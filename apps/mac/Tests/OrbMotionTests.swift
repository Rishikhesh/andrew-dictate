import XCTest

/// The orb keeps one shape for the whole take; the voice only moves its
/// speed and its size. These pin the numbers the design settled on.
final class OrbMotionTests: XCTestCase {
    func testHearingSpeedAndScaleFollowLoudness() {
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 0), 0.7, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 1), 2.5, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 0, reduceMotion: false), 1, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 1, reduceMotion: false), 1.14, accuracy: 1e-9)
    }

    func testWaitingIsSlowAndDim() {
        XCTAssertEqual(OrbMotion.speed(.waiting, loudness: 1), 0.6, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.waiting), 0.6, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.waiting, loudness: 1, reduceMotion: false), 1, accuracy: 1e-9)
    }

    func testTranscribingIsSteady() {
        XCTAssertEqual(OrbMotion.speed(.transcribing, loudness: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.transcribing), 1, accuracy: 1e-9)
    }

    func testLoudnessIsClampedAndNaNIsSilence() {
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: .nan), 0.7, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 5, reduceMotion: false), 1.14, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: -3, reduceMotion: false), 1, accuracy: 1e-9)
    }

    func testReduceMotionNeverScales() {
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 1, reduceMotion: true), 1, accuracy: 1e-9)
    }

    func testTimeOnlyMovesForward() {
        var motion = OrbMotion()
        var last = motion.time
        for i in 0..<100 {
            motion.advance(by: 0.016, phase: .hearing, loudness: Float(i % 7) / 6)
            XCTAssertGreaterThan(motion.time, last)
            last = motion.time
        }
    }

    func testLargeFrameGapIsCapped() {
        var motion = OrbMotion()
        motion.advance(by: 30, phase: .transcribing, loudness: 0)
        XCTAssertEqual(motion.time, 0.1, accuracy: 1e-9)
        motion.advance(by: -1, phase: .transcribing, loudness: 0)
        XCTAssertEqual(motion.time, 0.1, accuracy: 1e-9)
    }

    func testDefaultOrbIsComposingAndNamesExist() {
        XCTAssertEqual(ListeningOrb.defaultOrb, .composing)
        XCTAssertEqual(ListeningOrb.allCases.count, 9)
        for orb in ListeningOrb.allCases {
            XCTAssertFalse(orb.displayName.isEmpty, "\(orb) has no name")
        }
    }
}
