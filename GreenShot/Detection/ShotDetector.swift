import Foundation
import CoreGraphics

/// Analyzes the basketball's trajectory over time to determine if a shot was taken.
///
/// A shot is distinguished from a pass by:
/// 1. Significant upward movement (ball rises in frame)
/// 2. A parabolic arc (ball reaches apex then descends)
/// 3. Movement directed toward the hoop zone
/// 4. Arc height exceeds a minimum threshold (passes are flatter)
final class ShotDetector: ObservableObject {

    /// Fired when a shot is detected.
    var onShotDetected: (() -> Void)?

    /// The hoop location in normalized coordinates (0-1, origin top-left).
    /// Set by the user tapping on the screen.
    @Published var hoopLocation: CGPoint? = nil

    /// Current ball position for debug overlay.
    @Published var currentBallPosition: CGPoint? = nil

    /// Recent trajectory for debug overlay.
    @Published var recentTrajectory: [CGPoint] = []

    /// Whether the detector is armed (hoop has been set).
    var isArmed: Bool { hoopLocation != nil }

    // MARK: - Configuration

    /// Number of frames to keep in the trajectory buffer (~1.5 sec at 30fps).
    private let bufferSize = 45

    /// Minimum vertical rise (in normalized coords) to consider as upward movement.
    /// 0.05 = 5% of screen height.
    private let minRise: CGFloat = 0.05

    /// Minimum arc height above the starting position to distinguish from a pass.
    /// 0.08 = 8% of screen height.
    private let minArcHeight: CGFloat = 0.08

    /// How close (normalized) the ball's x must move toward the hoop to count.
    private let hoopProximityThreshold: CGFloat = 0.15

    /// Cooldown in seconds between shot triggers to prevent double-firing.
    private let cooldownDuration: TimeInterval = 2.5

    // MARK: - State

    private var trajectoryBuffer: [TrajectoryPoint] = []
    private var lastShotTime: TimeInterval = 0
    private var missedFrameCount = 0
    private let maxMissedFrames = 8 // allow brief occlusions

    // MARK: - Public

    /// Call when the ball is detected in a frame.
    func addDetection(position: CGPoint, confidence: Float) {
        let now = CACurrentMediaTime()
        missedFrameCount = 0

        let point = TrajectoryPoint(
            x: position.x,
            y: position.y,
            timestamp: now,
            confidence: confidence
        )

        trajectoryBuffer.append(point)
        if trajectoryBuffer.count > bufferSize {
            trajectoryBuffer.removeFirst(trajectoryBuffer.count - bufferSize)
        }

        // Update published properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentBallPosition = position
            self.recentTrajectory = self.trajectoryBuffer.map { $0.position }
        }

        analyzeTrajectory(at: now)
    }

    /// Call when no ball is detected in a frame.
    func addMiss() {
        missedFrameCount += 1
        if missedFrameCount > maxMissedFrames {
            // Ball lost for too long, clear trajectory
            trajectoryBuffer.removeAll()
            DispatchQueue.main.async { [weak self] in
                self?.currentBallPosition = nil
                self?.recentTrajectory = []
            }
        }
    }

    /// Reset all state.
    func reset() {
        trajectoryBuffer.removeAll()
        lastShotTime = 0
        missedFrameCount = 0
        DispatchQueue.main.async { [weak self] in
            self?.currentBallPosition = nil
            self?.recentTrajectory = []
        }
    }

    // MARK: - Analysis

    private func analyzeTrajectory(at now: TimeInterval) {
        // Need at least 15 frames of data to analyze
        guard trajectoryBuffer.count >= 15 else { return }

        // Cooldown check
        guard now - lastShotTime > cooldownDuration else { return }

        // Need a hoop location to determine shot direction
        guard let hoop = hoopLocation else { return }

        // Analyze the trajectory for shot characteristics
        if detectParabolicArc(toward: hoop) {
            lastShotTime = now
            trajectoryBuffer.removeAll()
            DispatchQueue.main.async { [weak self] in
                self?.recentTrajectory = []
            }
            onShotDetected?()
        }
    }

    private func detectParabolicArc(toward hoop: CGPoint) -> Bool {
        let points = trajectoryBuffer

        // Find the highest point (lowest y in top-left coords) in the trajectory
        guard let apex = points.min(by: { $0.y < $1.y }) else { return false }
        guard let apexIndex = points.firstIndex(where: { $0.timestamp == apex.timestamp }) else { return false }

        // Need points before and after apex
        guard apexIndex > 3 && apexIndex < points.count - 3 else { return false }

        // 1. Check upward movement: ball should rise before apex
        let preApexPoints = Array(points[0..<apexIndex])
        let startY = preApexPoints.first!.y
        let rise = startY - apex.y // positive means ball went up (y decreases going up)

        guard rise > minRise else { return false }

        // 2. Check descent after apex
        let postApexPoints = Array(points[apexIndex...])
        guard let lastPoint = postApexPoints.last else { return false }
        let descent = lastPoint.y - apex.y // positive means ball went down

        guard descent > minRise * 0.5 else { return false }

        // 3. Check arc height is sufficient (not a flat pass)
        guard rise > minArcHeight else { return false }

        // 4. Check movement toward hoop
        let startX = preApexPoints.first!.x
        let endX = lastPoint.x
        let distToHoopStart = abs(startX - hoop.x)
        let distToHoopEnd = abs(endX - hoop.x)

        // Ball should be closer to hoop at end than at start,
        // OR already near the hoop
        let movingTowardHoop = distToHoopEnd < distToHoopStart
        let nearHoop = distToHoopEnd < hoopProximityThreshold

        guard movingTowardHoop || nearHoop else { return false }

        print("[ShotDetector] 🏀 Shot detected! rise=\(rise) descent=\(descent) arc=\(rise)")
        return true
    }
}
