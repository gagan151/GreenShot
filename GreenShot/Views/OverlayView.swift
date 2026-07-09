import SwiftUI

/// Debug overlay drawn on top of the camera feed.
/// Shows the tracked ball position, trajectory trail, and hoop zone.
struct OverlayView: View {
    let ballPosition: CGPoint?     // normalized 0-1
    let trajectory: [CGPoint]      // normalized 0-1
    let hoopLocation: CGPoint?     // normalized 0-1
    let shotDetected: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            // Hoop zone
            if let hoop = hoopLocation {
                let hoopScreen = CGPoint(
                    x: hoop.x * size.width,
                    y: hoop.y * size.height
                )
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .position(hoopScreen)

                // Crosshair
                Image(systemName: "scope")
                    .foregroundColor(.red)
                    .font(.title2)
                    .position(hoopScreen)
            }

            // Trajectory trail
            if trajectory.count >= 2 {
                Path { path in
                    let first = trajectory[0]
                    path.move(to: CGPoint(
                        x: first.x * size.width,
                        y: first.y * size.height
                    ))
                    for point in trajectory.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: point.x * size.width,
                            y: point.y * size.height
                        ))
                    }
                }
                .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
            }

            // Current ball position
            if let ball = ballPosition {
                let ballScreen = CGPoint(
                    x: ball.x * size.width,
                    y: ball.y * size.height
                )
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .position(ballScreen)

                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .position(ballScreen)
            }

            // Shot detected flash
            if shotDetected {
                Color.green.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }
}
