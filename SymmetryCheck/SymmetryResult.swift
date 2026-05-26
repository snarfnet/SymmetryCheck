import Foundation
import Vision

struct SymmetryResult {
    var overall: Double = 0
    var leftEye: Double = 0
    var rightEye: Double = 0
    var eyeBalance: Double = 0
    var noseStraightness: Double = 0
    var mouthBalance: Double = 0
    var jawBalance: Double = 0
    var eyebrowBalance: Double = 0
    var landmarks: VNFaceLandmarks2D?
    var boundingBox: CGRect = .zero

    var summaryText: String {
        let lines = [
            String(format: "総合: %.1f%%", overall),
            String(format: "目のバランス: %.1f%%", eyeBalance),
            String(format: "眉のバランス: %.1f%%", eyebrowBalance),
            String(format: "鼻の直線性: %.1f%%", noseStraightness),
            String(format: "口のバランス: %.1f%%", mouthBalance),
            String(format: "輪郭バランス: %.1f%%", jawBalance),
        ]
        return lines.joined(separator: "\n")
    }

    var summaryTextEN: String {
        let lines = [
            String(format: "Overall: %.1f%%", overall),
            String(format: "Eye Balance: %.1f%%", eyeBalance),
            String(format: "Eyebrow Balance: %.1f%%", eyebrowBalance),
            String(format: "Nose Straightness: %.1f%%", noseStraightness),
            String(format: "Mouth Balance: %.1f%%", mouthBalance),
            String(format: "Jaw Balance: %.1f%%", jawBalance),
        ]
        return lines.joined(separator: "\n")
    }
}
