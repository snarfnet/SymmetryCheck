import UIKit
import Vision

enum PhotoComposer {

    static func compose(photo: UIImage, result: SymmetryResult, isEnglish: Bool) -> UIImage {
        let size = photo.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            photo.draw(at: .zero)

            let gc = ctx.cgContext
            let box = result.boundingBox
            let faceRect = CGRect(
                x: box.origin.x * size.width,
                y: (1 - box.origin.y - box.height) * size.height,
                width: box.width * size.width,
                height: box.height * size.height
            )

            // Draw face bounding box
            gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.7).cgColor)
            gc.setLineWidth(2)
            gc.stroke(faceRect)

            // Draw landmarks
            if let landmarks = result.landmarks {
                drawAllLandmarks(gc: gc, landmarks: landmarks, faceRect: faceRect, imageSize: size, boundingBox: box)
            }

            // Draw center line
            drawCenterLine(gc: gc, landmarks: result.landmarks, faceRect: faceRect, imageSize: size, boundingBox: box)

            // Draw data panel
            drawDataPanel(gc: gc, result: result, imageSize: size, isEnglish: isEnglish)

            // Draw individual scores near face parts
            drawPartScores(gc: gc, result: result, faceRect: faceRect, isEnglish: isEnglish)
        }
    }

    private static func drawAllLandmarks(gc: CGContext, landmarks: VNFaceLandmarks2D, faceRect: CGRect, imageSize: CGSize, boundingBox: CGRect) {
        let regions: [(VNFaceLandmarkRegion2D?, UIColor)] = [
            (landmarks.leftEye, .green),
            (landmarks.rightEye, .green),
            (landmarks.leftEyebrow, .yellow),
            (landmarks.rightEyebrow, .yellow),
            (landmarks.nose, .cyan),
            (landmarks.noseCrest, .cyan),
            (landmarks.outerLips, .magenta),
            (landmarks.innerLips, .magenta),
            (landmarks.faceContour, .white),
            (landmarks.leftPupil, .red),
            (landmarks.rightPupil, .red),
            (landmarks.medianLine, UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)),
        ]

        for (region, color) in regions {
            guard let region = region else { continue }
            let points = FaceAnalyzer.pointsArray(region)
            gc.setFillColor(color.cgColor)

            for point in points {
                let x = (boundingBox.origin.x + point.x * boundingBox.width) * imageSize.width
                let y = (1 - (boundingBox.origin.y + point.y * boundingBox.height)) * imageSize.height
                gc.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
            }
        }
    }

    private static func drawCenterLine(gc: CGContext, landmarks: VNFaceLandmarks2D?, faceRect: CGRect, imageSize: CGSize, boundingBox: CGRect) {
        guard let median = landmarks?.medianLine else { return }
        let points = FaceAnalyzer.pointsArray(median)
        guard points.count >= 2 else { return }

        gc.setStrokeColor(UIColor.orange.withAlphaComponent(0.8).cgColor)
        gc.setLineWidth(1.5)
        gc.setLineDash(phase: 0, lengths: [6, 4])

        let first = points.first!
        let startX = (boundingBox.origin.x + first.x * boundingBox.width) * imageSize.width
        let startY = (1 - (boundingBox.origin.y + first.y * boundingBox.height)) * imageSize.height
        gc.move(to: CGPoint(x: startX, y: startY))

        for i in 1..<points.count {
            let x = (boundingBox.origin.x + points[i].x * boundingBox.width) * imageSize.width
            let y = (1 - (boundingBox.origin.y + points[i].y * boundingBox.height)) * imageSize.height
            gc.addLine(to: CGPoint(x: x, y: y))
        }
        gc.strokePath()
        gc.setLineDash(phase: 0, lengths: [])
    }

    private static func drawDataPanel(gc: CGContext, result: SymmetryResult, imageSize: CGSize, isEnglish: Bool) {
        let panelWidth: CGFloat = min(imageSize.width * 0.45, 420)
        let panelHeight: CGFloat = 280
        let margin: CGFloat = 16
        let panelRect = CGRect(x: margin, y: margin, width: panelWidth, height: panelHeight)

        // Semi-transparent background
        gc.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        gc.fill(panelRect)
        gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
        gc.setLineWidth(1)
        gc.stroke(panelRect)

        let titleFont = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let labelFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        let valueFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)

        let title = isEnglish ? "SYMMETRY ANALYSIS" : "対称性分析レポート"
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.cyan]
        (title as NSString).draw(at: CGPoint(x: margin + 12, y: margin + 10), withAttributes: titleAttr)

        let items: [(String, Double, UIColor)] = [
            (isEnglish ? "Overall" : "総合スコア", result.overall, .white),
            (isEnglish ? "Eye Balance" : "目のバランス", result.eyeBalance, .green),
            (isEnglish ? "Eyebrow" : "眉のバランス", result.eyebrowBalance, .yellow),
            (isEnglish ? "Nose" : "鼻の直線性", result.noseStraightness, .cyan),
            (isEnglish ? "Mouth" : "口のバランス", result.mouthBalance, .magenta),
            (isEnglish ? "Jaw" : "輪郭バランス", result.jawBalance, .white),
        ]

        for (i, item) in items.enumerated() {
            let y = margin + 40 + CGFloat(i) * 36
            let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: item.2.withAlphaComponent(0.9)]
            (item.0 as NSString).draw(at: CGPoint(x: margin + 12, y: y), withAttributes: labelAttr)

            let grade = gradeFor(item.1)
            let valueText = String(format: "%.1f%% %@", item.1, grade)
            let valueColor = colorForScore(item.1)
            let valAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColor]
            (valueText as NSString).draw(at: CGPoint(x: margin + panelWidth - 140, y: y), withAttributes: valAttr)
        }
    }

    private static func drawPartScores(gc: CGContext, result: SymmetryResult, faceRect: CGRect, isEnglish: Bool) {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)

        let items: [(String, Double, CGPoint)] = [
            (isEnglish ? "L.Eye" : "左目", result.eyeBalance, CGPoint(x: faceRect.minX - 60, y: faceRect.midY - 30)),
            (isEnglish ? "R.Eye" : "右目", result.eyeBalance, CGPoint(x: faceRect.maxX + 8, y: faceRect.midY - 30)),
            (isEnglish ? "Nose" : "鼻", result.noseStraightness, CGPoint(x: faceRect.maxX + 8, y: faceRect.midY + 10)),
            (isEnglish ? "Mouth" : "口", result.mouthBalance, CGPoint(x: faceRect.maxX + 8, y: faceRect.midY + 50)),
        ]

        for item in items {
            let text = String(format: "%@ %.0f%%", item.0, item.1)
            let color = colorForScore(item.1)
            let bg = UIColor.black.withAlphaComponent(0.6)
            let textSize = (text as NSString).size(withAttributes: [.font: font])
            let bgRect = CGRect(x: item.2.x - 2, y: item.2.y - 1, width: textSize.width + 4, height: textSize.height + 2)
            gc.setFillColor(bg.cgColor)
            gc.fill(bgRect)
            let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (text as NSString).draw(at: item.2, withAttributes: attr)
        }
    }

    private static func gradeFor(_ score: Double) -> String {
        switch score {
        case 95...: return "S+"
        case 90..<95: return "S"
        case 85..<90: return "A+"
        case 80..<85: return "A"
        case 75..<80: return "B+"
        case 70..<75: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }

    private static func colorForScore(_ score: Double) -> UIColor {
        switch score {
        case 90...: return UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1)
        case 80..<90: return UIColor(red: 0.5, green: 1, blue: 0.8, alpha: 1)
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        }
    }
}
