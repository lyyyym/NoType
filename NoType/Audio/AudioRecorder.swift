import AVFoundation
import Foundation

/// Records microphone audio into an `AudioBuffer` using `AVAudioEngine`.
///
/// Captures 16-bit PCM, 16 kHz, mono. See `research.md` §3.
final class AudioRecorder {

    /// Called with an error description when recording cannot start or fails.
    var onFailure: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private let buffer: AudioBuffer

    /// Maximum recording duration in seconds (FR-014).
    let maxDurationSeconds: TimeInterval

    private var maxTimer: Timer?
    private(set) var isRecording = false

    init(buffer: AudioBuffer, maxDurationSeconds: TimeInterval = 60) {
        self.buffer = buffer
        self.maxDurationSeconds = maxDurationSeconds
    }

    /// Starts capturing audio. Must be called on the main thread.
    /// - Throws: `AudioError` if permission is missing or the engine fails.
    func start() throws {
        assert(Thread.isMainThread, "AudioRecorder.start must run on the main thread")

        try ensureRecordPermission()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("[AudioRecorder] input format: \(inputFormat)")

        // Target format: 16-bit PCM, 16 kHz, mono.
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(buffer.sampleRate),
            channels: AVAudioChannelCount(buffer.channels),
            interleaved: true
        ) else {
            throw AudioError.engineStartFailed("could not create target audio format")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.engineStartFailed("could not create audio converter")
        }

        buffer.reset()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] pcmBuffer, _ in
            guard let self = self else { return }
            self.convertAndAppend(pcmBuffer: pcmBuffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            try engine.start()
            print("[AudioRecorder] engine started")
        } catch {
            throw AudioError.engineStartFailed(error.localizedDescription)
        }
        isRecording = true

        // Auto-stop after the configured maximum duration (FR-014).
        let timer = Timer(timeInterval: maxDurationSeconds, repeats: false) { [weak self] _ in
            self?.stop(reason: .maxDuration)
        }
        RunLoop.main.add(timer, forMode: .common)
        maxTimer = timer
    }

    private func ensureRecordPermission() throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return
        case .denied:
            throw AudioError.permissionDenied
        case .undetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            DispatchQueue.global(qos: .userInitiated).async {
                AVAudioApplication.requestRecordPermission { ok in
                    granted = ok
                    semaphore.signal()
                }
            }
            semaphore.wait()
            guard granted else { throw AudioError.permissionDenied }
        @unknown default:
            throw AudioError.permissionDenied
        }
    }

    private func convertAndAppend(pcmBuffer: AVAudioPCMBuffer,
                                  converter: AVAudioConverter,
                                  targetFormat: AVAudioFormat) {
        let inputFrames = pcmBuffer.frameLength
        guard inputFrames > 0 else { return }

        // Allocate enough capacity for the worst case (same number of output frames).
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: inputFrames) else {
            print("[AudioRecorder] could not allocate output buffer")
            return
        }

        var conversionError: NSError?
        var pendingInput: AVAudioPCMBuffer? = pcmBuffer
        let status = converter.convert(to: converted, error: &conversionError) { _, statusOut in
            if let input = pendingInput {
                pendingInput = nil
                statusOut.pointee = .haveData
                return input
            }
            statusOut.pointee = .noDataNow
            return nil
        }

        if status == .error || conversionError != nil {
            print("[AudioRecorder] converter error: \(conversionError?.localizedDescription ?? "unknown")")
            return
        }

        guard converted.frameLength > 0 else { return }

        if let raw = converted.int16ChannelData?[0] {
            let byteCount = Int(converted.frameLength) * Int(targetFormat.channelCount) * 2
            let data = Data(bytes: raw, count: byteCount)
            buffer.append(data)
            print("[AudioRecorder] appended \(byteCount) bytes (total \(buffer.byteCount))")
        } else {
            print("[AudioRecorder] converted buffer has no Int16 data")
        }
    }

    enum StopReason {
        case userReleased
        case maxDuration
    }

    /// Stops capturing audio. Must be called on the main thread.
    func stop(reason: StopReason = .userReleased) {
        assert(Thread.isMainThread, "AudioRecorder.stop must run on the main thread")
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        maxTimer?.invalidate()
        maxTimer = nil
        isRecording = false
        print("[AudioRecorder] stopped, captured \(buffer.byteCount) bytes")
    }
}
