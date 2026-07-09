import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var shotDetector = ShotDetector()
    @StateObject private var soundManager = SoundManager()

    @State private var ballDetector = BallDetector()
    @State private var isRunning = false
    @State private var showSoundPicker = false
    @State private var showShotFlash = false
    @State private var shotCount = 0
    @State private var statusMessage = "Tap the hoop location to begin"

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(session: cameraManager.captureSession)
                .ignoresSafeArea()
                .onTapGesture { location in
                    handleTap(at: location)
                }

            // Detection overlay
            OverlayView(
                ballPosition: shotDetector.currentBallPosition,
                trajectory: shotDetector.recentTrajectory,
                hoopLocation: shotDetector.hoopLocation,
                shotDetected: showShotFlash
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // UI Controls
            VStack {
                // Top bar
                HStack {
                    // Status
                    Text(statusMessage)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)

                    Spacer()

                    // Shot counter
                    Text("Shots: \(shotCount)")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding()

                Spacer()

                // Bottom controls
                HStack(spacing: 20) {
                    // Sound picker button
                    Button {
                        showSoundPicker = true
                    } label: {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                    }

                    // Start/Stop button
                    Button {
                        toggleDetection()
                    } label: {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(isRunning ? .red : .green)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial)
                            .cornerRadius(35)
                    }

                    // Reset hoop button
                    Button {
                        resetHoop()
                    } label: {
                        Image(systemName: "scope")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupDetectionPipeline()
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .sheet(isPresented: $showSoundPicker) {
            SoundPickerView(soundManager: soundManager)
        }
    }

    // MARK: - Setup

    private func setupDetectionPipeline() {
        // Wire up: camera frame → ball detector → shot detector → sound
        ballDetector.onBallDetected = { [weak shotDetector] position, confidence in
            shotDetector?.addDetection(position: position, confidence: confidence)
        }
        ballDetector.onNoBall = { [weak shotDetector] in
            shotDetector?.addMiss()
        }

        shotDetector.onShotDetected = { [weak soundManager] in
            soundManager?.playShot()
            DispatchQueue.main.async {
                shotCount += 1
                triggerFlash()
            }
        }

        cameraManager.onFrame = { [ballDetector] sampleBuffer in
            guard isRunning else { return }
            ballDetector.detect(in: sampleBuffer)
        }
    }

    // MARK: - Actions

    private func handleTap(at location: CGPoint) {
        // Convert screen tap to normalized coordinates
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let screenSize = window.bounds.size
        let normalized = CGPoint(
            x: location.x / screenSize.width,
            y: location.y / screenSize.height
        )

        shotDetector.hoopLocation = normalized
        statusMessage = "Hoop set! Tap play to start detection"
    }

    private func toggleDetection() {
        if isRunning {
            isRunning = false
            statusMessage = shotDetector.isArmed ? "Paused" : "Tap the hoop location to begin"
            shotDetector.reset()
        } else {
            guard shotDetector.isArmed else {
                statusMessage = "⚠️ Tap on the hoop first!"
                return
            }
            isRunning = true
            statusMessage = "Detecting shots..."
        }
    }

    private func resetHoop() {
        isRunning = false
        shotDetector.hoopLocation = nil
        shotDetector.reset()
        shotCount = 0
        statusMessage = "Tap the hoop location to begin"
    }

    private func triggerFlash() {
        showShotFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showShotFlash = false
        }
    }
}
