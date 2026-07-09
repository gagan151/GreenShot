import Vision
import CoreML
import AVFoundation
import CoreGraphics

/// Detects basketballs in video frames using YOLOv8n via Vision + CoreML.
final class BallDetector {
    /// Called when a ball is detected. Provides the center point in normalized
    /// coordinates (0-1, origin top-left) and the confidence.
    var onBallDetected: ((CGPoint, Float) -> Void)?

    /// Called when no ball is found in the frame.
    var onNoBall: (() -> Void)?

    private var request: VNCoreMLRequest?
    private let confidenceThreshold: Float = 0.3

    // COCO class index for "sports ball"
    private let sportsBallLabel = "sports ball"

    init() {
        setupModel()
    }

    // MARK: - Public

    /// Process a single video frame to detect the basketball.
    func detect(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = request else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[BallDetector] Detection failed: \(error)")
        }
    }

    // MARK: - Private

    private func setupModel() {
        guard let modelURL = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "yolov8n", withExtension: "mlpackage") else {
            // Try compiled model path from mlpackage
            if let compiledURL = findCompiledModel() {
                loadModel(from: compiledURL)
            } else {
                print("[BallDetector] Could not find YOLOv8n model in bundle")
            }
            return
        }
        loadModel(from: modelURL)
    }

    private func findCompiledModel() -> URL? {
        // When an .mlpackage is added to Xcode, it gets compiled to .mlmodelc
        // Search for it in the bundle
        return Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first {
            $0.lastPathComponent.contains("yolov8n")
        }
    }

    private func loadModel(from url: URL) {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use Neural Engine + GPU + CPU
            let mlModel = try MLModel(contentsOf: url, configuration: config)
            let visionModel = try VNCoreMLModel(for: mlModel)

            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.handleResults(request: request, error: error)
            }
            // YOLOv8 expects square input; let Vision handle scaling
            request.imageCropAndScaleOption = .scaleFill
            self.request = request
            print("[BallDetector] Model loaded successfully")
        } catch {
            print("[BallDetector] Failed to load model: \(error)")
        }
    }

    private func handleResults(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            onNoBall?()
            return
        }

        // Find the best "sports ball" detection
        let ballDetections = results.filter { observation in
            guard let topLabel = observation.labels.first else { return false }
            return topLabel.identifier == sportsBallLabel
                && topLabel.confidence >= confidenceThreshold
        }

        guard let bestBall = ballDetections.max(by: { $0.confidence < $1.confidence }) else {
            onNoBall?()
            return
        }

        // Vision coordinates: origin bottom-left, normalized 0-1
        // Convert to top-left origin for screen coordinates
        let bbox = bestBall.boundingBox
        let centerX = bbox.midX
        let centerY = 1.0 - bbox.midY // flip Y axis

        onBallDetected?(
            CGPoint(x: centerX, y: centerY),
            bestBall.labels.first?.confidence ?? 0
        )
    }
}
