import CoreMotion
import Foundation
import os

/// Owns the pure motion-data pipeline: sample validation, low-pass smoothing,
/// pitch-history buffering, and attitude-to-display-angle conversion.
///
/// `HeadphoneMotionManager` delegates the derivation of pitch/roll/yaw and
/// pitch history here, then mirrors the results onto its own observable state
/// so existing UI call sites and public APIs are unchanged. This follows the
/// same service-plus-mirror convention already used by
/// `PostureEvaluationService` and `SessionTimingService`.
@Observable
@MainActor
final class HeadphoneMotionPipeline {

    /// Most recent samples, oldest first. Bounded by `maxDataPoints` (FIFO).
    private(set) var pitchHistory: [Double] = []

    /// The smoothed pitch (degrees) produced by the last accepted sample.
    private(set) var pitch: Double = 0.0

    private let maxDataPoints = MotionConstants.maxDataPoints

    /// Derived display values for a single accepted motion sample.
    ///
    /// Angles are in degrees. Returned by `process` so the caller can apply the
    /// session/posture/connection side-effects that remain in the manager.
    struct ProcessedSample: Equatable {
        let pitch: Double
        let roll: Double
        let yaw: Double
        let timestamp: Date
    }

    // MARK: - Validation

    /// Returns `false` for NaN/Infinite/out-of-range attitude, matching the
    /// historical `validateMotionData` rules so corrupt samples are skipped.
    func validate(_ motion: CMDeviceMotion) -> Bool {
        let attitude = motion.attitude

        // Check for NaN values
        guard !attitude.pitch.isNaN,
              !attitude.roll.isNaN,
              !attitude.yaw.isNaN else {
            Logger.motion.warning("NaN values detected in motion data - skipping update")
            return false
        }

        // Check for infinite values
        guard !attitude.pitch.isInfinite,
              !attitude.roll.isInfinite,
              !attitude.yaw.isInfinite else {
            Logger.motion.warning("Infinite values detected in motion data - skipping update")
            return false
        }

        // Check for reasonable value ranges
        let validRange = -Double.pi...Double.pi
        guard validRange.contains(attitude.pitch),
              validRange.contains(attitude.roll),
              validRange.contains(attitude.yaw) else {
            Logger.motion.warning("Out of range values detected - skipping update")
            return false
        }

        return true
    }

    // MARK: - Low-Pass Filter

    /// Single-pole low-pass filter used to smooth incoming pitch samples.
    /// Pure function: output depends only on its inputs.
    func lowPassFilter(current: Double, previous: Double) -> Double {
        return previous * (1.0 - MotionConstants.lowPassFilterFactor) + current
            * MotionConstants.lowPassFilterFactor
    }

    // MARK: - Sample Processing

    /// Validates the sample, applies the low-pass filter to pitch, converts the
    /// attitude from radians to degrees, appends the smoothed pitch to the
    /// bounded history, and returns the derived values.
    ///
    /// Returns `nil` when the sample fails validation, leaving history and the
    /// last smoothed pitch untouched.
    @discardableResult
    func process(
        _ motion: CMDeviceMotion,
        previousPitch: Double,
        at timestamp: Date = Date()
    ) -> ProcessedSample? {
        guard validate(motion) else { return nil }

        let newPitch = lowPassFilter(
            current: motion.attitude.pitch * 180 / .pi,
            previous: previousPitch
        )

        pitch = newPitch
        appendToHistory(newPitch)

        return ProcessedSample(
            pitch: newPitch,
            roll: motion.attitude.roll * 180 / .pi,
            yaw: motion.attitude.yaw * 180 / .pi,
            timestamp: timestamp
        )
    }

    // MARK: - History

    /// Resets smoothed pitch and history. Used when starting/stopping a session.
    func reset() {
        pitch = 0.0
        pitchHistory.removeAll()
    }

    private func appendToHistory(_ newPitch: Double) {
        pitchHistory.append(newPitch)
        if pitchHistory.count > maxDataPoints {
            pitchHistory.removeFirst()
        }
    }
}
