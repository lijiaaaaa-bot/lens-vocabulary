import Foundation

struct OCRResult: Equatable {
    let text: String
    let latencyMilliseconds: Double
    let observedAt: Date
}
