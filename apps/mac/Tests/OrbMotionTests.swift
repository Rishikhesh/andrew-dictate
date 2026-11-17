import XCTest

/// The orb keeps one shape for the whole take; the voice only moves its
/// speed and its size. These pin the numbers the design settled on.
final class OrbMotionTests: XCTestCase {
    // the voice has to be seen: between words the orb draws in and dims,
    // a loud syllable swells it, brightens it and speeds it up.
    func testHearingSpeedAndScaleFollowLoudness() {
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 1), 3.0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 0, reduceMotion: false), 0.85, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 1, reduceMotion: false), 1.3, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.hearing, loudness: 0), 0.7, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.hearing, loudness: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.chipScale(.hearing, loudness: 0, reduceMotion: false), 1.0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.chipScale(.hearing, loudness: 1, reduceMotion: false), 1.18, accuracy: 1e-9)
    }

    // normal speech sits mid-range (about 0.5): the change has to be plain
    // there, not only at the top.
    func testOrdinarySpeechIsClearlyVisible() {
        let quiet = OrbMotion.scale(.hearing, loudness: 0, reduceMotion: false)
        let talking = OrbMotion.scale(.hearing, loudness: 0.5, reduceMotion: false)
        XCTAssertGreaterThanOrEqual(talking / quiet, 1.25)
    }

    func testWaitingIsSlowAndDim() {
        XCTAssertEqual(OrbMotion.speed(.waiting, loudness: 1), 0.6, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.waiting, loudness: 1), 0.6, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.waiting, loudness: 1, reduceMotion: false), 0.85, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.chipScale(.waiting, loudness: 1, reduceMotion: false), 1.0, accuracy: 1e-9)
    }

    func testTranscribingIsSteady() {
        XCTAssertEqual(OrbMotion.speed(.transcribing, loudness: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.opacity(.transcribing, loudness: 1), 1, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.transcribing, loudness: 1, reduceMotion: false), 1.0, accuracy: 1e-9)
    }

    func testLoudnessIsClampedAndNaNIsSilence() {
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: .nan), 0.5, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 5, reduceMotion: false), 1.3, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: -3, reduceMotion: false), 0.85, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.chipScale(.hearing, loudness: .infinity, reduceMotion: false), 1.0, accuracy: 1e-9)
    }

    func testReduceMotionNeverScales() {
        XCTAssertEqual(OrbMotion.scale(.hearing, loudness: 1, reduceMotion: true), 1, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.chipScale(.hearing, loudness: 1, reduceMotion: true), 1, accuracy: 1e-9)
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

    // final review, finding 1: one orb across the whole take means one
    // phase rule, outside the view's switch.
    func testPhaseForEachLampState() {
        XCTAssertNil(OrbPhase.forLamp(.idle, isHearing: false))
        XCTAssertEqual(OrbPhase.forLamp(.prewarming, isHearing: false), .waiting)
        XCTAssertEqual(OrbPhase.forLamp(.recording, isHearing: false), .waiting)
        XCTAssertEqual(OrbPhase.forLamp(.recording, isHearing: true), .hearing)
        XCTAssertEqual(OrbPhase.forLamp(.transcribing, isHearing: true), .transcribing)
    }

    // final review, finding 2: a frozen time is raw engine time, so the
    // orb's own preset pace has to be applied by us.
    func testEngineTimeAppliesThePresetSpeed() {
        var motion = OrbMotion()
        motion.advance(by: 0.05, phase: .transcribing, loudness: 0)
        XCTAssertEqual(motion.engineTime(presetSpeed: 2.34), 0.05 * 2.34, accuracy: 1e-9)
    }

    func testSizeChoicesMatchTheApprovedRenders() {
        XCTAssertEqual(OrbSizeChoice.small.orb, 36); XCTAssertEqual(OrbSizeChoice.small.chip, 44)
        XCTAssertEqual(OrbSizeChoice.medium.orb, 54); XCTAssertEqual(OrbSizeChoice.medium.chip, 64)
        XCTAssertEqual(OrbSizeChoice.large.orb, 70); XCTAssertEqual(OrbSizeChoice.large.chip, 80)
        XCTAssertEqual(OrbSizeChoice.defaultSize, .large)
    }

    // tone: higher than your usual voice lifts and stretches the orb and
    // quickens it; lower settles and widens it and slows it.
    func testHighToneLiftsStretchesAndQuickens() {
        XCTAssertEqual(OrbMotion.lift(.hearing, tone: 1, reduceMotion: false), 0.08, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.lift(.hearing, tone: -1, reduceMotion: false), -0.08, accuracy: 1e-9)
        let high = OrbMotion.stretch(.hearing, tone: 1, reduceMotion: false)
        XCTAssertEqual(high.x, 0.92, accuracy: 1e-9)
        XCTAssertEqual(high.y, 1.12, accuracy: 1e-9)
        let low = OrbMotion.stretch(.hearing, tone: -1, reduceMotion: false)
        XCTAssertEqual(low.x, 1.08, accuracy: 1e-9)
        XCTAssertEqual(low.y, 0.88, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 0, tone: 1), 0.5 * 1.35, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.speed(.hearing, loudness: 0, tone: -1), 0.5 * 0.65, accuracy: 1e-9)
    }

    func testToneOnlyMovesTheOrbWhileHearing() {
        XCTAssertEqual(OrbMotion.lift(.transcribing, tone: 1, reduceMotion: false), 0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.stretch(.waiting, tone: 1, reduceMotion: false).y, 1, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.speed(.transcribing, loudness: 0, tone: 1), 1.0, accuracy: 1e-9)
    }

    func testToneIsClampedAndReduceMotionHoldsStill() {
        XCTAssertEqual(OrbMotion.lift(.hearing, tone: 9, reduceMotion: false), 0.08, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.lift(.hearing, tone: .nan, reduceMotion: false), 0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.lift(.hearing, tone: 1, reduceMotion: true), 0, accuracy: 1e-9)
        XCTAssertEqual(OrbMotion.stretch(.hearing, tone: 1, reduceMotion: true).y, 1, accuracy: 1e-9)
    }
}
