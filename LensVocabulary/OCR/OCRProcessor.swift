import CoreImage
import Vision

final class OCRProcessor {
    func recognizeText(in pixelBuffer: CVPixelBuffer, regionOfInterest: CGRect) -> OCRResult? {
        let start = CFAbsoluteTimeGetCurrent()
        var recognizedText = ""

        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            recognizedText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.018
        request.regionOfInterest = regionOfInterest

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let latency = (CFAbsoluteTimeGetCurrent() - start) * 1_000
        let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else { return nil }
        return OCRResult(text: trimmed, latencyMilliseconds: latency, observedAt: Date())
    }
}
