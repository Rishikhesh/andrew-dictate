import XCTest

/// The orb follows your voice's tone: higher than you usually speak lifts
/// it, lower settles it. These pin the pitch reading and the tone it makes,
/// with made-up voices whose pitch is known.
final class PitchEstimatorTests: XCTestCase {
    /// a voice-like tone: a fundamental and a few falling harmonics.
    private func voice(_ hz: Double, rate: Double = 48_000, seconds: Double = 0.1, amplitude: Float = 0.2) -> [Float] {
        let n = Int(rate * seconds)
        return (0..<n).map { i in
            let t = Double(i) / rate
            var v = 0.0
            for (k, gain) in [1.0, 0.6, 0.4, 0.25, 0.15].enumerated() {
                v += gain * sin(2 * .pi * hz * Double(k + 1) * t)
            }
            return Float(v / 2.4) * amplitude
        }
    }

    func testFindsALowVoice() throws {
        let hz = try XCTUnwrap(PitchEstimator.fundamental(of: voice(110), sampleRate: 48_000))
        XCTAssertEqual(hz, 110, accuracy: 3)
    }

    func testFindsAHighVoice() throws {
        let hz = try XCTUnwrap(PitchEstimator.fundamental(of: voice(310), sampleRate: 48_000))
        XCTAssertEqual(hz, 310, accuracy: 6)
    }

    func testDoesNotJumpAnOctaveOnARichVoice() throws {
        let hz = try XCTUnwrap(PitchEstimator.fundamental(of: voice(200), sampleRate: 48_000))
        XCTAssertEqual(hz, 200, accuracy: 5)
    }

    func testWorksAtOtherSampleRates() throws {
        let hz = try XCTUnwrap(PitchEstimator.fundamental(of: voice(150, rate: 44_100), sampleRate: 44_100))
        XCTAssertEqual(hz, 150, accuracy: 4)
        let low = try XCTUnwrap(PitchEstimator.fundamental(of: voice(150, rate: 16_000), sampleRate: 16_000))
        XCTAssertEqual(low, 150, accuracy: 4)
    }

    func testSilenceAndNoiseHaveNoPitch() {
        XCTAssertNil(PitchEstimator.fundamental(of: [Float](repeating: 0, count: 4_800), sampleRate: 48_000))
        var seed: UInt64 = 42
        let noise: [Float] = (0..<4_800).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: seed >> 11) % 2000) / 10_000
        }
        XCTAssertNil(PitchEstimator.fundamental(of: noise, sampleRate: 48_000))
    }

    func testTooShortABufferHasNoPitch() {
        XCTAssertNil(PitchEstimator.fundamental(of: voice(150, seconds: 0.004), sampleRate: 48_000))
    }

    func testToneIsRelativeToYourOwnVoice() {
        var tracker = ToneTracker()
        for _ in 0..<90 { tracker.update(pitch: 150, dt: 0.033) }
        XCTAssertEqual(tracker.tone, 0, accuracy: 0.05)

        for _ in 0..<9 { tracker.update(pitch: 150 * pow(2, 0.5), dt: 0.033) }
        XCTAssertGreaterThan(tracker.tone, 0.6, "half an octave up should read clearly high")

        var low = ToneTracker()
        for _ in 0..<90 { low.update(pitch: 150, dt: 0.033) }
        for _ in 0..<9 { low.update(pitch: 150 / pow(2, 0.5), dt: 0.033) }
        XCTAssertLessThan(low.tone, -0.6, "half an octave down should read clearly low")
    }

    func testADeepVoiceAndAHighVoiceBothSitAtZero() {
        var deep = ToneTracker(), high = ToneTracker()
        for _ in 0..<90 { deep.update(pitch: 95, dt: 0.033); high.update(pitch: 260, dt: 0.033) }
        XCTAssertEqual(deep.tone, 0, accuracy: 0.05)
        XCTAssertEqual(high.tone, 0, accuracy: 0.05)
    }

    func testToneEasesBackWithoutAVoiceAndStaysInRange() {
        var tracker = ToneTracker()
        for _ in 0..<60 { tracker.update(pitch: 150, dt: 0.033) }
        for _ in 0..<9 { tracker.update(pitch: 600, dt: 0.033) }
        XCTAssertLessThanOrEqual(tracker.tone, 1)
        for _ in 0..<30 { tracker.update(pitch: nil, dt: 0.033) }
        XCTAssertEqual(tracker.tone, 0, accuracy: 0.05)
    }
}
