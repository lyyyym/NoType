import AppKit
import Foundation

/// Orchestrates the dictation flow:
/// shortcut press → record → ASR → LLM polish (fallback to raw) → inject.
///
/// Runs on the main actor because it drives AppKit/AVFoundation/CGEvent.
@MainActor
final class DictationController {

    private let config: Configuration
    private let recorder: AudioRecorder
    private let buffer: AudioBuffer
    private let asr: ASRClient
    private let llm: LLMClient
    private let injector: KeyboardInjector
    private let status: StatusBarController

    private var session: RecordingSession?

    init(config: Configuration,
         status: StatusBarController,
         buffer: AudioBuffer = AudioBuffer(),
         recorder: AudioRecorder? = nil,
         asr: ASRClient? = nil,
         llm: LLMClient? = nil,
         injector: KeyboardInjector = KeyboardInjector()) {
        self.config = config
        self.status = status
        self.buffer = buffer
        self.recorder = recorder ?? AudioRecorder(buffer: buffer)
        self.asr = asr ?? ASRClient(config: config.asr)
        self.llm = llm ?? LLMClient(config: config.llm)
        self.injector = injector

        self.recorder.onFailure = { [weak self] detail in
            Task { @MainActor in self?.fail(with: detail) }
        }
    }

    // MARK: - Shortcut callbacks

    func didPressShortcut() {
        startRecording()
    }

    func didReleaseShortcut() {
        stopAndProcess()
    }

    // MARK: - Flow

    private func startRecording() {
        guard session == nil || session?.status == .idle || session?.status == .failed else { return }
        let newSession = RecordingSession(status: .idle)
        _ = newSession.transition(to: .recording)
        session = newSession
        status.update(.recording)

        do {
            try recorder.start()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    private func stopAndProcess() {
        recorder.stop()
        guard let session = session, session.status == .recording else { return }
        _ = session.transition(to: .processing)
        status.update(.processing)

        // Capture the buffer once, then free it immediately (FR-012).
        let wav = buffer.wavData()
        buffer.reset()

        if wav.count <= 44 {
            // No PCM payload captured (empty audio).
            fail(with: TranscriptionError.emptyTranscription("no audio captured").localizedDescription)
            return
        }

        Task { [weak self, asr, llm, injector, status] in
            guard let self = self else { return }
            await self.process(wav: wav, session: session, asr: asr, llm: llm, injector: injector, status: status)
        }
    }

    private func process(wav: Data,
                         session: RecordingSession,
                         asr: ASRClient,
                         llm: LLMClient,
                         injector: KeyboardInjector,
                         status: StatusBarController) async {
        // 1. ASR
        let rawText: String
        do {
            rawText = try await asr.transcribe(wavData: wav)
        } catch {
            self.fail(with: error.localizedDescription)
            return
        }
        session.setRawTranscription(rawText)

        // 2. LLM polish, fall back to raw text on failure (FR-013).
        var finalText = rawText
        var usedFallback = false
        do {
            finalText = try await llm.polish(transcript: rawText)
        } catch {
            usedFallback = true
            finalText = PolishPrompt.normalize(rawText)
        }
        session.setPolishedText(finalText)

        // 3. Inject at the cursor.
        do {
            try injector.inject(text: finalText)
            _ = session.transition(to: usedFallback ? .insertedRaw : .inserted)
            status.update(.success)
        } catch {
            self.fail(with: error.localizedDescription)
        }
    }

    private func fail(with detail: String) {
        print("[NoType] fail: \(detail)")
        session?.setError(detail)
        _ = session?.transition(to: .failed)
        status.update(.error)
        status.showError(detail)
        recorder.stop()
    }
}
