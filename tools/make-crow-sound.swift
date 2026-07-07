// Synthesizes the "cock-a-doodle-doo" chiptune jingle played on activation
// (Settings → General → "Play crow sound"). Square-wave, 8-bit flavor to match
// the pixel-art branding.
//
// Usage (from the repo root):
//   swift tools/make-crow-sound.swift

import Foundation

let outPath = "Latch/Resources/crow.wav"
let sampleRate = 44100.0
let amplitude = 0.24

// cock-a-doodle-doo — five syllables; the last one slides down like a real crow.
// (startHz, endHz, seconds)
let notes: [(Double, Double, Double)] = [
    (392, 392, 0.11),   // G4  "cock"
    (440, 440, 0.09),   // A4  "a"
    (523, 523, 0.16),   // C5  "doo"
    (440, 440, 0.10),   // A4  "dle"
    (587, 466, 0.38),   // D5→B♭4 "dooo" falling
]
let gap = 0.025

var samples: [Int16] = []

func square(_ phase: Double) -> Double {
    phase.truncatingRemainder(dividingBy: 1.0) < 0.35 ? 1.0 : -1.0
}

for (startHz, endHz, dur) in notes {
    let n = Int(dur * sampleRate)
    var phase = 0.0
    for i in 0..<n {
        let t = Double(i) / Double(n)
        let hz = startHz + (endHz - startHz) * t
        phase += hz / sampleRate
        // Envelope: fast attack, gentle decay, short release
        let attack = min(1.0, Double(i) / (0.006 * sampleRate))
        let release = min(1.0, Double(n - i) / (0.03 * sampleRate))
        let decay = 1.0 - 0.35 * t
        let v = square(phase) * amplitude * attack * release * decay
        samples.append(Int16(max(-1, min(1, v)) * 32767))
    }
    samples.append(contentsOf: [Int16](repeating: 0, count: Int(gap * sampleRate)))
}

// Minimal WAV (RIFF, PCM 16-bit mono)
var data = Data()
func append(_ s: String) { data.append(s.data(using: .ascii)!) }
func append32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
func append16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

let byteCount = UInt32(samples.count * 2)
append("RIFF"); append32(36 + byteCount); append("WAVE")
append("fmt "); append32(16); append16(1); append16(1)
append32(UInt32(sampleRate)); append32(UInt32(sampleRate) * 2); append16(2); append16(16)
append("data"); append32(byteCount)
samples.withUnsafeBytes { data.append(contentsOf: $0) }

try? FileManager.default.createDirectory(atPath: (outPath as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(data.count) bytes, \(String(format: "%.2f", Double(samples.count) / sampleRate))s)")
