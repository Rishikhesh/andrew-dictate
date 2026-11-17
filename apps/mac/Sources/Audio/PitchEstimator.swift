import Accelerate
import Foundation

/// the pitch of a voice in one tap buffer, so the orb can follow your tone
/// and not only your loudness. normalised autocorrelation over the range a
/// speaking voice uses, on a copy decimated to about 12 kHz; nil when the
/// buffer is too quiet, too short, or not voiced (noise, breath, clicks).
enum PitchEstimator {
    static let lowestHz = 70.0
    static let highestHz = 450.0
    /// below this the buffer is silence for our purposes (about -50 dBFS).
    static let minimumRMS: Float = 0.003
    /// how alike the signal must be to itself one period later to count as
    /// a voice.
    static let minimumClarity: Float = 0.6

    static func fundamental(of samples: [Float], sampleRate: Double) -> Double? {
        guard sampleRate > 0, !samples.isEmpty else {
            return nil
        }

        // decimate with a boxcar average, which doubles as the anti-alias
        // filter: a voice's pitch lives far below 6 kHz.
        let step = max(1, Int(sampleRate / 12_000))
        let rate = sampleRate / Double(step)
        var x = [Float](repeating: 0, count: samples.count / step)
        guard x.count > 0 else {
            return nil
        }
        for i in 0..<x.count {
            var sum: Float = 0
            for j in 0..<step {
                sum += samples[i * step + j]
            }
            x[i] = sum / Float(step)
        }

        var mean: Float = 0
        vDSP_meanv(x, 1, &mean, vDSP_Length(x.count))
        var negativeMean = -mean
        vDSP_vsadd(x, 1, &negativeMean, &x, 1, vDSP_Length(x.count))

        var rms: Float = 0
        vDSP_rmsqv(x, 1, &rms, vDSP_Length(x.count))
        guard rms >= minimumRMS else {
            return nil
        }

        let minLag = max(2, Int(floor(rate / highestHz)))
        let maxLag = Int(ceil(rate / lowestHz))
        // two periods of the lowest voice, or the reading is a guess.
        guard x.count > maxLag * 2 else {
            return nil
        }

        var clarity = [Float](repeating: 0, count: maxLag + 2)
        x.withUnsafeBufferPointer { p in
            guard let base = p.baseAddress else { return }
            for lag in minLag...(maxLag + 1) {
                let n = vDSP_Length(x.count - lag)
                var cross: Float = 0, a: Float = 0, b: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &cross, n)
                vDSP_svesq(base, 1, &a, n)
                vDSP_svesq(base + lag, 1, &b, n)
                let energy = sqrt(a * b)
                clarity[lag] = energy > 0 ? cross / energy : 0
            }
        }

        let best = clarity[minLag...maxLag].max() ?? 0
        guard best >= minimumClarity else {
            return nil
        }

        // the first peak that is nearly as clear as the best: a voice is
        // just as alike to itself two periods on, and taking that one would
        // read an octave low.
        var chosen = minLag
        for lag in minLag...maxLag {
            let isPeak = clarity[lag] >= clarity[lag - 1] && clarity[lag] >= clarity[lag + 1]
            if isPeak, clarity[lag] >= best * 0.9 {
                chosen = lag
                break
            }
        }

        // parabolic interpolation between the neighbours for a sub-sample lag.
        let left = Double(clarity[chosen - 1]), centre = Double(clarity[chosen]), right = Double(clarity[chosen + 1])
        let denominator = left - 2 * centre + right
        let offset = denominator != 0 ? 0.5 * (left - right) / denominator : 0
        let period = Double(chosen) + max(-0.5, min(0.5, offset))
        return rate / period
    }
}

/// your tone against your own usual voice: -1 is half an octave below how
/// you have been speaking, +1 half an octave above. the baseline drifts
/// slowly with you, so a deep voice and a high voice both rest at 0.
struct ToneTracker: Equatable, Sendable {
    private(set) var tone: Double = 0
    private(set) var baseline: Double?

    /// how far from the baseline reads as fully high or low, in octaves.
    static let fullRange = 0.5
    static let followSeconds = 0.08
    static let baselineSeconds = 4.0
    static let restSeconds = 0.25

    mutating func update(pitch: Double?, dt: Double) {
        let dt = max(0, dt.isFinite ? dt : 0)
        guard let pitch, pitch.isFinite, pitch > 0 else {
            tone += (0 - tone) * min(1, dt / Self.restSeconds)
            return
        }
        let octaves = log2(pitch)
        let base = baseline ?? octaves
        let target = max(-1, min(1, (octaves - base) / Self.fullRange))
        tone += (target - tone) * min(1, dt / Self.followSeconds)
        baseline = base + (octaves - base) * min(1, dt / Self.baselineSeconds)
    }
}
