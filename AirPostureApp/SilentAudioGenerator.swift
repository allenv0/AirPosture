import Foundation

/// Shared utility for generating silent WAV audio data used by background audio managers.
/// Replaces duplicate `createSilentAudioData()` implementations across the codebase.
enum SilentAudioGenerator {
    static let sharedData = createSilentWAVData()

    static func createSilentWAVData() -> Data {
        let sampleRate: UInt32 = 44_100
        let numSamples = Int(sampleRate)
        let dataSize = numSamples * 2

        var wavData = Data()
        wavData.append(Data("RIFF".utf8))
        wavData.append(withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        wavData.append(Data("WAVE".utf8))
        wavData.append(Data("fmt ".utf8))
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: (sampleRate * 2).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })
        wavData.append(Data("data".utf8))
        wavData.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        wavData.append(Data(repeating: 0, count: dataSize))
        return wavData
    }
}
