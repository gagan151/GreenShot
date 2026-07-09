import Foundation
import CoreGraphics

/// A single tracked position of the basketball in normalized coordinates (0-1).
/// Origin is top-left to match screen coordinates.
struct TrajectoryPoint {
    /// Normalized x position (0 = left, 1 = right)
    let x: CGFloat
    /// Normalized y position (0 = top, 1 = bottom)
    let y: CGFloat
    /// Timestamp when this position was recorded
    let timestamp: TimeInterval
    /// Confidence of the detection (0-1)
    let confidence: Float

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}
