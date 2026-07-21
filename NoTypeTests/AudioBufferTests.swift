import Foundation
import Testing
@testable import NoType

@Suite("AudioBuffer")
struct AudioBufferTests {

    @Test func wavHeaderIsCanonicalForEmptyPayload() {
        let wav = AudioBuffer.makeWAV(pcm: Data(), sampleRate: 16_000, channels: 1, bitsPerSample: 16)
        // Header is exactly 44 bytes when there is no PCM payload.
        #expect(wav.count == 44)
        #expect(String(data: wav.subdata(in: 0..<4), encoding: .utf8) == "RIFF")
        #expect(String(data: wav.subdata(in: 8..<12), encoding: .utf8) == "WAVE")
        #expect(String(data: wav.subdata(in: 12..<16), encoding: .utf8) == "fmt ")
        #expect(wav.subdata(in: 4..<8) == Data([36, 0, 0, 0]))          // chunkSize = 36
        #expect(wav.subdata(in: 24..<28) == Data([0x80, 0x3E, 0, 0]))   // 16000 little-endian
        #expect(String(data: wav.subdata(in: 36..<40), encoding: .utf8) == "data")
        #expect(wav.subdata(in: 40..<44) == Data([0, 0, 0, 0]))
    }

    @Test func wavIncludesPCMAndCorrectSizes() {
        let pcm = Data(repeating: 0x41, count: 1600)
        let wav = AudioBuffer.makeWAV(pcm: pcm, sampleRate: 16_000, channels: 1, bitsPerSample: 16)
        #expect(wav.count == 44 + 1600)
        #expect(wav.subdata(in: 4..<8) == Data([0x64, 0x06, 0, 0]))   // 36 + 1600 = 1636
        #expect(wav.subdata(in: 40..<44) == Data([0x40, 0x06, 0, 0])) // data size = 1600
        #expect(wav.suffix(1600) == pcm)
    }

    @Test func appendAndResetTrackByteCount() {
        let buffer = AudioBuffer()
        buffer.append(Data(repeating: 0x01, count: 100))
        #expect(buffer.byteCount == 100)
        buffer.append(Data(repeating: 0x02, count: 50))
        #expect(buffer.byteCount == 150)
        buffer.reset()
        #expect(buffer.byteCount == 0)
    }
}
