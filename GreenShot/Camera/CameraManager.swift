import AVFoundation
import UIKit

/// Manages the AVCaptureSession and delivers video frames via a delegate callback.
final class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()

    /// Called on a background queue for each video frame.
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.greenshot.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()

    override init() {
        super.init()
    }

    // MARK: - Public

    func start() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    // MARK: - Private

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720 // good balance of quality vs performance

        // Camera input (back wide-angle camera)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            print("[CameraManager] Failed to configure camera input")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // Video output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let processingQueue = DispatchQueue(label: "com.greenshot.camera.processing")
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            print("[CameraManager] Failed to add video output")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(videoOutput)

        // Lock to landscape-right orientation so court view is stable
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0 // landscape
            }
        }

        captureSession.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
