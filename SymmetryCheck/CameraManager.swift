import AVFoundation
import Vision
import UIKit

@Observable
final class CameraManager: NSObject {
    let session = AVCaptureSession()
    var currentResult: SymmetryResult?
    var allLandmarkPoints: [(CGPoint, String)] = []
    var isFrontCamera = true
    var capturedImage: UIImage?
    var isCapturing = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private var captureCompletion: ((UIImage?) -> Void)?

    func start() {
        guard !session.isRunning else { return }
        queue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func flipCamera() {
        isFrontCamera.toggle()
        queue.async { [weak self] in
            self?.configureSession()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        isCapturing = true
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        session.sessionPreset = .high

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            if isFrontCamera { connection.isVideoMirrored = true }
        }

        session.commitConfiguration()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation],
                  let face = results.first,
                  let landmarks = face.landmarks else {
                DispatchQueue.main.async { self?.currentResult = nil }
                return
            }

            let result = FaceAnalyzer.analyze(landmarks: landmarks, boundingBox: face.boundingBox)

            DispatchQueue.main.async {
                self?.currentResult = result
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async { self.isCapturing = false }
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(nil)
            return
        }
        captureCompletion?(image)
    }
}
