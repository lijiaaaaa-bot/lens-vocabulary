import AVFoundation
import Foundation

enum CameraAuthorizationState: Equatable {
    case unknown
    case authorized
    case denied
    case unavailable
}

struct CameraStats: Equatable {
    var lastLatencyMilliseconds: Double = 0
    var processedFrames: Int = 0
    var lastUpdatedAt: Date?
}

struct FocusWindow: Equatable {
    var x: CGFloat = 0.12
    var y: CGFloat = 0.60
    var width: CGFloat = 0.76
    var height: CGFloat = 0.18

    var visionRegionOfInterest: CGRect {
        CGRect(x: x, y: 1 - y - height, width: width, height: height)
    }

    mutating func move(by translation: CGSize, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        x += translation.width / size.width
        y += translation.height / size.height
        clamp()
    }

    mutating func resize(by translation: CGSize, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        width += translation.width / size.width
        height += translation.height / size.height
        clamp()
    }

    private mutating func clamp() {
        width = min(max(width, 0.25), 0.96)
        height = min(max(height, 0.08), 0.45)
        x = min(max(x, 0.02), 0.98 - width)
        y = min(max(y, 0.02), 0.98 - height)
    }
}
