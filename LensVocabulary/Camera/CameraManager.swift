import AVFoundation
import Combine
import UIKit

final class CameraManager: NSObject, ObservableObject {
    @Published var authorizationState: CameraAuthorizationState = .unknown
    @Published var latestText = ""
    @Published var stableText = ""
    @Published var stats = CameraStats()

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "LensVocabulary.camera.session")
    private let videoQueue = DispatchQueue(label: "LensVocabulary.camera.video")
    private let ocrProcessor = OCRProcessor()
    private var focusWindow = FocusWindow()
    private var isProcessingFrame = false
    private var lastProcessedAt = Date.distantPast
    private var previousText = ""
    private var repeatedTextCount = 0

    override init() {
        super.init()
        checkAuthorization()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
            configureIfNeeded()
        case .notDetermined:
            authorizationState = .unknown
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .unavailable
        }
    }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.authorizationState = granted ? .authorized : .denied
                if granted {
                    self?.configureIfNeeded()
                    self?.start()
                }
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning == false else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func updateFocusWindow(_ focusWindow: FocusWindow) {
        videoQueue.async { [weak self] in
            self?.focusWindow = focusWindow
        }
    }

    private func configureIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.inputs.isEmpty else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.authorizationState = .unavailable
                }
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            output.setSampleBufferDelegate(self, queue: self.videoQueue)

            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }

            output.connection(with: .video)?.videoOrientation = .portrait
            self.session.commitConfiguration()
        }
    }

    private func handle(result: OCRResult) {
        let normalized = normalize(result.text)
        guard normalized.isEmpty == false else { return }

        if normalized == previousText {
            repeatedTextCount += 1
        } else {
            repeatedTextCount = 0
            previousText = normalized
        }

        let shouldPromote = repeatedTextCount >= 1 || stableText.isEmpty

        DispatchQueue.main.async {
            self.latestText = normalized
            if shouldPromote {
                self.stableText = normalized
            }
            self.stats.lastLatencyMilliseconds = result.latencyMilliseconds
            self.stats.processedFrames += 1
            self.stats.lastUpdatedAt = result.observedAt
        }
    }

    private func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessingFrame == false else { return }
        guard Date().timeIntervalSince(lastProcessedAt) > 0.45 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessingFrame = true
        lastProcessedAt = Date()
        let roi = focusWindow.visionRegionOfInterest
        let result = ocrProcessor.recognizeText(in: pixelBuffer, regionOfInterest: roi)
        isProcessingFrame = false

        if let result {
            handle(result: result)
        }
    }
}
