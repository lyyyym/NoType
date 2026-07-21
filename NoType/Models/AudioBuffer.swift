import Foundation

/// In-memory container for captured PCM audio and WAV generation.
///
/// Fixed format: 16-bit PCM, 16 kHz, mono. See `data-model.md`.
final class AudioBuffer {

    let sampleRate: Int
    let channels: Int
    let bitsPerSample: Int

    private(set) var pcmBytes: Data = Data()
    private let lock = NSLock()

    init(sampleRate: Int = 16_000, channels: Int = 1, bitsPerSample: Int = 16) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
    }

    /// Appends raw PCM sample bytes. Safe to call from an audio input queue.
    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        pcmBytes.append(data)
    }

    /// Number of PCM bytes captured so far.
    var byteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pcmBytes.count
    }

    /// Clears captured samples. Called after transcription so audio is not retained (FR-012).
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        pcmBytes.removeAll(keepingCapacity: false)
    }

    /// Returns a WAV-formatted `Data` blob (header + PCM) suitable for ASR upload.
    func wavData() -> Data {
        lock.lock()
        let pcm = pcmBytes
        lock.unlock()
        return AudioBuffer.makeWAV(
            pcm: pcm,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: bitsPerSample
        )
    }

    /// Builds a canonical WAV (RIFF) blob for the given raw PCM bytes.
    /// Pure function; tested in `AudioBufferTests`.
    static func makeWAV(pcm: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcm.count
        let chunkSize = 36 + dataSize

        var out = Data()
        out.reserveCapacity(44 + dataSize)
        out.append(contentsOf: utf8("RIFF"))
        out.append(contentsOf: littleEndian(UInt32(chunkSize)))
        out.append(contentsOf: utf8("WAVE"))
        out.append(contentsOf: utf8("fmt "))
        out.append(contentsOf: littleEndian(UInt32(16)))     // PCM fmt chunk size
        out.append(contentsOf: littleEndian(UInt16(1)))      // audio format = PCM
        out.append(contentsOf: littleEndian(UInt16(channels)))
        out.append(contentsOf: littleEndian(UInt32(sampleRate)))
        out.append(contentsOf: littleEndian(UInt32(byteRate)))
        out.append(contentsOf: littleEndian(UInt16(blockAlign)))
        out.append(contentsOf: littleEndian(UInt16(bitsPerSample)))
        out.append(contentsOf: utf8("data"))
        out.append(contentsOf: littleEndian(UInt32(dataSize)))
        out.append(pcm)
        return out
    }

    private static func utf8(_ s: String) -> [UInt8] {
        return Array(s.utf8)
    }

    private static func littleEndian(_ value: UInt16) -> [UInt8] {
        return [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func littleEndian(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }
}
