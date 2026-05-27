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
            (landmarks.outerLips, .systemPink),
            (landmarks.innerLips, .systemPink),
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
        let scale: CGFloat = max(1.0, imageSize.width / 1000)
        let panelWidth: CGFloat = min(imageSize.width * 0.55, 600 * scale)
        let margin: CGFloat = 20 * scale

        let titleFont = UIFont.monospacedSystemFont(ofSize: 28 * scale, weight: .bold)
        let overallFont = UIFont.monospacedSystemFont(ofSize: 36 * scale, weight: .black)
        let labelFont = UIFont.monospacedSystemFont(ofSize: 20 * scale, weight: .bold)
        let valueFont = UIFont.monospacedSystemFont(ofSize: 20 * scale, weight: .bold)
        let commentFont = UIFont.monospacedSystemFont(ofSize: 16 * scale, weight: .medium)
        let footerFont = UIFont.monospacedSystemFont(ofSize: 14 * scale, weight: .medium)

        let rowHeight: CGFloat = 56 * scale
        let panelHeight: CGFloat = 80 * scale + rowHeight * 6 + 50 * scale + 36 * scale
        let panelRect = CGRect(x: margin, y: margin, width: panelWidth, height: panelHeight)

        // Background
        gc.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
        gc.fill(panelRect)
        gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
        gc.setLineWidth(2)
        gc.stroke(panelRect)

        var y = margin + 14 * scale

        // Title
        let title = isEnglish ? "SYMMETRY ANALYSIS" : "対称性分析レポート"
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.cyan]
        (title as NSString).draw(at: CGPoint(x: margin + 16, y: y), withAttributes: titleAttr)
        y += 40 * scale

        // Overall
        let overallText = String(format: "%@ %.1f%%", gradeFor(result.overall), result.overall)
        let overallColor = colorForScore(result.overall)
        let overallAttr: [NSAttributedString.Key: Any] = [.font: overallFont, .foregroundColor: overallColor]
        (overallText as NSString).draw(at: CGPoint(x: margin + 16, y: y), withAttributes: overallAttr)
        y += 44 * scale

        let overallComment = result.overallComment(isEnglish: isEnglish)
        let commentAttr: [NSAttributedString.Key: Any] = [.font: commentFont, .foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        (overallComment as NSString).draw(at: CGPoint(x: margin + 16, y: y), withAttributes: commentAttr)
        y += 32 * scale

        // Divider
        gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.3).cgColor)
        gc.setLineWidth(1)
        gc.move(to: CGPoint(x: margin + 10, y: y))
        gc.addLine(to: CGPoint(x: margin + panelWidth - 10, y: y))
        gc.strokePath()
        y += 10 * scale

        // Detail rows
        let items: [(String, Double, UIColor, String)] = [
            (isEnglish ? "Eye" : "目", result.eyeBalance, .green, result.eyeComment(isEnglish: isEnglish)),
            (isEnglish ? "Eyebrow" : "眉", result.eyebrowBalance, .yellow, result.eyebrowComment(isEnglish: isEnglish)),
            (isEnglish ? "Nose" : "鼻", result.noseStraightness, .cyan, result.noseComment(isEnglish: isEnglish)),
            (isEnglish ? "Mouth" : "口", result.mouthBalance, UIColor.systemPink, result.mouthComment(isEnglish: isEnglish)),
            (isEnglish ? "Jaw" : "輪郭", result.jawBalance, .white, result.jawComment(isEnglish: isEnglish)),
        ]

        for item in items {
            // Label + score
            let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: item.2.withAlphaComponent(0.9)]
            (item.0 as NSString).draw(at: CGPoint(x: margin + 16, y: y), withAttributes: labelAttr)

            let grade = gradeFor(item.1)
            let valueText = String(format: "%.1f%% %@", item.1, grade)
            let valueColor = colorForScore(item.1)
            let valAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColor]
            let valSize = (valueText as NSString).size(withAttributes: valAttr)
            (valueText as NSString).draw(at: CGPoint(x: margin + panelWidth - valSize.width - 16, y: y), withAttributes: valAttr)

            // Comment
            let cmtAttr: [NSAttributedString.Key: Any] = [.font: commentFont, .foregroundColor: valueColor.withAlphaComponent(0.7)]
            (item.3 as NSString).draw(at: CGPoint(x: margin + 16, y: y + 26 * scale), withAttributes: cmtAttr)

            y += rowHeight
        }

        // Footer
        y += 4 * scale
        let footer = isEnglish ? "76-Point Landmark Detection" : "76点ランドマーク検出"
        let footerAttr: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        (footer as NSString).draw(at: CGPoint(x: margin + 16, y: y), withAttributes: footerAttr)
    }

    private static func drawPartScores(gc: CGContext, result: SymmetryResult, faceRect: CGRect, isEnglish: Bool) {
        let scale: CGFloat = max(1.0, faceRect.width / 300)
        let font = UIFont.monospacedSystemFont(ofSize: 16 * scale, weight: .bold)
        let commentFont = UIFont.monospacedSystemFont(ofSize: 13 * scale, weight: .medium)

        let items: [(String, Double, String, CGPoint)] = [
            (isEnglish ? "Eye" : "目", result.eyeBalance, result.eyeComment(isEnglish: isEnglish),
             CGPoint(x: faceRect.maxX + 12, y: faceRect.midY - 60 * scale)),
            (isEnglish ? "Nose" : "鼻", result.noseStraightness, result.noseComment(isEnglish: isEnglish),
             CGPoint(x: faceRect.maxX + 12, y: faceRect.midY + 10)),
            (isEnglish ? "Mouth" : "口", result.mouthBalance, result.mouthComment(isEnglish: isEnglish),
             CGPoint(x: faceRect.maxX + 12, y: faceRect.midY + 70 * scale)),
        ]

        for item in items {
            let text = String(format: "%@ %.0f%%", item.0, item.1)
            let color = colorForScore(item.1)
            let bg = UIColor.black.withAlphaComponent(0.7)

            let textSize = (text as NSString).size(withAttributes: [.font: font])
            let commentSize = (item.2 as NSString).size(withAttributes: [.font: commentFont])
            let bgWidth = max(textSize.width, commentSize.width) + 12
            let bgHeight = textSize.height + commentSize.height + 8

            let bgRect = CGRect(x: item.3.x - 4, y: item.3.y - 3, width: bgWidth, height: bgHeight)
            gc.setFillColor(bg.cgColor)
            gc.fill(bgRect)

            let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (text as NSString).draw(at: item.3, withAttributes: attr)

            let cmtAttr: [NSAttributedString.Key: Any] = [.font: commentFont, .foregroundColor: color.withAlphaComponent(0.7)]
            (item.2 as NSString).draw(at: CGPoint(x: item.3.x, y: item.3.y + textSize.height + 2), withAttributes: cmtAttr)
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
