import AppKit
import Foundation

/// Orchestrates the dictation flow:
/// shortcut press → record → ASR → LLM polish (mode-aware; fallback to raw) → inject.
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
    private let status: any DictationStatusReporting
    private let history: HistoryStore
    private let stats: StatsStore
    private let dictionary: DictionaryStore
    private let modes: ModeStore
    private let bubble: FloatingBubbleWindow?
    private let previewController: PreviewWindowController?

    private var session: RecordingSession?
    /// The mode selected by the most recent shortcut press; drives polishing.
    private var selectedMode: PolishingMode?
    /// The app that was frontmost when recording started; re-activated on preview confirm.
    private var targetApp: FrontmostApp?

    init(config: Configuration,
         status: any DictationStatusReporting,
         buffer: AudioBuffer = AudioBuffer(),
         recorder: AudioRecorder? = nil,
         asr: ASRClient? = nil,
         llm: LLMClient? = nil,
         injector: KeyboardInjector = KeyboardInjector(),
         history: HistoryStore? = nil,
         stats: StatsStore? = nil,
         dictionary: DictionaryStore? = nil,
         modes: ModeStore? = nil,
         bubble: FloatingBubbleWindow? = nil,
         preview: PreviewWindowController? = nil) {
        self.config = config
        self.status = status
        self.buffer = buffer
        self.recorder = recorder ?? AudioRecorder(buffer: buffer)
        self.asr = asr ?? ASRClient(config: config.asr)
        self.llm = llm ?? LLMClient(config: config.llm)
        self.injector = injector
        self.history = history ?? HistoryStore()
        self.stats = stats ?? StatsStore()
        self.dictionary = dictionary ?? DictionaryStore()
        if let modes = modes {
            self.modes = modes
        } else {
            let store = ModeStore()
            store.load(legacyEverydayShortcut: config.shortcut)
            self.modes = store
        }
        self.bubble = bubble ?? (config.showFloatingBubble ? FloatingBubbleWindow() : nil)
        self.previewController = preview ?? (config.showPreviewBeforeInjection ? PreviewWindowController() : nil)

        self.recorder.onFailure = { [weak self] detail in
            Task { @MainActor in self?.fail(with: detail) }
        }
    }

    // MARK: - Shortcut callbacks

    func didPressShortcut(modeID: UUID) {
        guard let mode = modes.mode(for: modeID) else {
            fail(with: "No mode found for this shortcut.")
            return
        }
        selectedMode = mode
        // Capture the target app before anything (e.g. a preview panel) takes focus.
        targetApp = FrontmostApp.current
        startRecording()
    }

    func didReleaseShortcut(modeID: UUID) {
        stopAndProcess()
    }

    // MARK: - Flow

    private func startRecording() {
        guard session == nil || session?.status == .idle || session?.status == .failed else { return }
        let newSession = RecordingSession(status: .idle)
        _ = newSession.transition(to: .recording)
        session = newSession
        status.update(.recording, modeName: selectedMode?.name)
        bubble?.show(position: config.bubblePosition)

        do {
            try recorder.start()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    private func stopAndProcess() {
        recorder.stop()
        bubble?.hide()
        guard let session = session, session.status == .recording else { return }
        _ = session.transition(to: .processing)
        status.update(.processing, modeName: nil)

        // Capture the buffer once, then free it immediately (FR-012).
        let wav = buffer.wavData()
        buffer.reset()

        if wav.count <= 44 {
            // No PCM payload captured (empty audio).
            fail(with: TranscriptionError.emptyTranscription("no audio captured").localizedDescription)
            return
        }

        let mode = selectedMode
        Task { [weak self, asr, llm, injector, status] in
            guard let self = self else { return }
            await self.process(wav: wav, session: session, mode: mode, asr: asr, llm: llm, injector: injector, status: status)
        }
    }

    private func process(wav: Data,
                         session: RecordingSession,
                         mode: PolishingMode?,
                         asr: ASRClient,
                         llm: LLMClient,
                         injector: KeyboardInjector,
                         status: any DictationStatusReporting) async {
        // 1. ASR
        let rawText: String
        do {
            rawText = try await asr.transcribe(wavData: wav)
        } catch {
            self.fail(with: error.localizedDescription)
            return
        }
        session.setRawTranscription(rawText)

        // 2. LLM polish using the selected mode's instruction (fall back to raw on failure).
        var finalText = rawText
        let dictionaryHint = dictionary.promptHint()
        let instruction = mode?.instruction ?? ""
        let outputLanguage = mode?.outputLanguage
        do {
            finalText = try await llm.polish(transcript: rawText,
                                             dictionaryHint: dictionaryHint,
                                             systemInstruction: instruction,
                                             outputLanguage: outputLanguage)
        } catch {
            finalText = PolishPrompt.normalize(rawText)
        }
        session.setPolishedText(finalText)

        // 3. Inject (optionally via an editable preview first).
        if config.showPreviewBeforeInjection, let preview = previewController {
            presentPreview(text: finalText, mode: mode, rawText: rawText, session: session, preview: preview)
        } else {
            injectAndRecord(rawText: rawText, finalText: finalText, session: session)
        }
    }

    /// Shows the editable preview; on confirm re-activates the target app and injects,
    /// on cancel discards without injecting or recording.
    private func presentPreview(text: String,
                                mode: PolishingMode?,
                                rawText: String,
                                session: RecordingSession,
                                preview: PreviewWindowController) {
        preview.onConfirm = { [weak self] edited in
            Task { @MainActor in
                guard let self = self else { return }
                self.targetApp?.reactivate()
                self.injectAndRecord(rawText: rawText, finalText: edited, session: session)
            }
        }
        preview.onCancel = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                print("[NoType] preview cancelled")
                self.resetSession()
                self.status.update(.idle, modeName: nil)
            }
        }
        preview.present(text: text, modeName: mode?.name)
    }

    /// Injects `finalText`, records history + stats, and resets the session.
    private func injectAndRecord(rawText: String, finalText: String, session: RecordingSession) {
        do {
            try injector.inject(text: finalText)
            _ = session.transition(to: .inserted)
            status.update(.success, modeName: nil)
            let entry = RecordingEntry(rawText: rawText, polishedText: finalText)
            history.append(entry)
            stats.record(words: entry.wordCount)
        } catch {
            self.fail(with: error.localizedDescription)
            return
        }
        resetSession()
    }

    /// Clears the per-recording state so the shortcut can be reused (FR-016).
    private func resetSession() {
        session = nil
        selectedMode = nil
        targetApp = nil
    }

    private func fail(with detail: String) {
        print("[NoType] fail: \(detail)")
        bubble?.hide()
        session?.setError(detail)
        _ = session?.transition(to: .failed)
        status.update(.error, modeName: nil)
        status.showError(detail)
        recorder.stop()
        resetSession()
    }
}
