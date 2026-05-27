import UIKit
import Vision

enum PhotoComposer {

    static func compose(photo: UIImage, result: SymmetryResult, isEnglish: Bool) -> UIImage {
        let photoSize = photo.size
        // Report on LEFT (60%), Photo on RIGHT (40%)
        let reportRatio: CGFloat = 0.6
        let photoRatio: CGFloat = 0.4
        let totalWidth = photoSize.width / photoRatio  // photo fills 40% of width
        let totalHeight = photoSize.height
        let reportWidth = totalWidth * reportRatio
        let outputSize = CGSize(width: totalWidth, height: totalHeight)

        let renderer = UIGraphicsImageRenderer(size: outputSize)

        return renderer.image { ctx in
            let gc = ctx.cgContext

            // Black background for report area
            gc.setFillColor(UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1).cgColor)
            gc.fill(CGRect(x: 0, y: 0, width: reportWidth, height: totalHeight))

            // Draw photo on right side with landmarks
            let photoRect = CGRect(x: reportWidth, y: 0, width: photoSize.width, height: photoSize.height)
            photo.draw(in: photoRect)

            // Draw landmarks on photo
            let box = result.boundingBox
            let photoFaceRect = CGRect(
                x: reportWidth + box.origin.x * photoSize.width,
                y: (1 - box.origin.y - box.height) * photoSize.height,
                width: box.width * photoSize.width,
                height: box.height * photoSize.height
            )

            gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.7).cgColor)
            gc.setLineWidth(2)
            gc.stroke(photoFaceRect)

            if let landmarks = result.landmarks {
                drawLandmarksOnPhoto(gc: gc, landmarks: landmarks, boundingBox: box,
                                     photoOrigin: CGPoint(x: reportWidth, y: 0), photoSize: photoSize)
            }
            drawCenterLineOnPhoto(gc: gc, landmarks: result.landmarks, boundingBox: box,
                                  photoOrigin: CGPoint(x: reportWidth, y: 0), photoSize: photoSize)

            // Draw report panel on left side
            drawReport(gc: gc, result: result, reportWidth: reportWidth, totalHeight: totalHeight, isEnglish: isEnglish)
        }
    }

    // MARK: - Report Panel

    private static func drawReport(gc: CGContext, result: SymmetryResult, reportWidth: CGFloat, totalHeight: CGFloat, isEnglish: Bool) {
        let s = reportWidth / 500  // scale factor based on panel width
        let pad: CGFloat = 30 * s
        var y: CGFloat = 40 * s

        // Title
        let titleFont = UIFont.monospacedSystemFont(ofSize: 32 * s, weight: .bold)
        let title = isEnglish ? "SYMMETRY ANALYSIS" : "対称性分析レポート"
        draw(title, at: CGPoint(x: pad, y: y), font: titleFont, color: .cyan, gc: gc)
        y += 50 * s

        // Subtitle
        let subFont = UIFont.monospacedSystemFont(ofSize: 18 * s, weight: .medium)
        let sub = isEnglish ? "76-Point Facial Landmark Detection" : "76点 顔面ランドマーク検出"
        draw(sub, at: CGPoint(x: pad, y: y), font: subFont, color: UIColor.white.withAlphaComponent(0.5), gc: gc)
        y += 50 * s

        // Divider
        drawDivider(gc: gc, y: y, x1: pad, x2: reportWidth - pad)
        y += 20 * s

        // Overall score - BIG
        let gradeFont = UIFont.monospacedSystemFont(ofSize: 72 * s, weight: .black)
        let grade = gradeFor(result.overall)
        let gradeColor = colorForScore(result.overall)
        draw(grade, at: CGPoint(x: pad, y: y), font: gradeFont, color: gradeColor, gc: gc)

        let scoreFont = UIFont.monospacedSystemFont(ofSize: 48 * s, weight: .black)
        let scoreText = String(format: "%.1f%%", result.overall)
        let gradeSize = (grade as NSString).size(withAttributes: [.font: gradeFont])
        draw(scoreText, at: CGPoint(x: pad + gradeSize.width + 16 * s, y: y + 20 * s), font: scoreFont, color: gradeColor, gc: gc)
        y += 90 * s

        // Overall comment
        let commentFont = UIFont.monospacedSystemFont(ofSize: 24 * s, weight: .medium)
        draw(result.overallComment(isEnglish: isEnglish), at: CGPoint(x: pad, y: y),
             font: commentFont, color: UIColor.white.withAlphaComponent(0.7), gc: gc)
        y += 50 * s

        // Divider
        drawDivider(gc: gc, y: y, x1: pad, x2: reportWidth - pad)
        y += 30 * s

        // Detail rows
        let labelFont = UIFont.monospacedSystemFont(ofSize: 28 * s, weight: .bold)
        let valueFont = UIFont.monospacedSystemFont(ofSize: 28 * s, weight: .bold)
        let cmtFont = UIFont.monospacedSystemFont(ofSize: 20 * s, weight: .medium)
        let barHeight: CGFloat = 12 * s
        let rowSpacing: CGFloat = 90 * s

        let items: [(String, Double, UIColor, String)] = [
            (isEnglish ? "Eye Balance" : "目のバランス", result.eyeBalance, .green, result.eyeComment(isEnglish: isEnglish)),
            (isEnglish ? "Eyebrow" : "眉のバランス", result.eyebrowBalance, .yellow, result.eyebrowComment(isEnglish: isEnglish)),
            (isEnglish ? "Nose" : "鼻の直線性", result.noseStraightness, .cyan, result.noseComment(isEnglish: isEnglish)),
            (isEnglish ? "Mouth" : "口のバランス", result.mouthBalance, UIColor.systemPink, result.mouthComment(isEnglish: isEnglish)),
            (isEnglish ? "Jaw Line" : "輪郭バランス", result.jawBalance, .white, result.jawComment(isEnglish: isEnglish)),
        ]

        for item in items {
            // Label
            draw(item.0, at: CGPoint(x: pad, y: y), font: labelFont, color: item.2.withAlphaComponent(0.9), gc: gc)

            // Grade + value on right
            let itemGrade = gradeFor(item.1)
            let valText = String(format: "%@ %.1f%%", itemGrade, item.1)
            let valColor = colorForScore(item.1)
            let valSize = (valText as NSString).size(withAttributes: [.font: valueFont])
            draw(valText, at: CGPoint(x: reportWidth - pad - valSize.width, y: y), font: valueFont, color: valColor, gc: gc)

            // Progress bar
            let barY = y + 34 * s
            let barWidth = reportWidth - pad * 2
            gc.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            gc.fill(CGRect(x: pad, y: barY, width: barWidth, height: barHeight))
            gc.setFillColor(valColor.cgColor)
            gc.fill(CGRect(x: pad, y: barY, width: barWidth * min(CGFloat(item.1) / 100, 1), height: barHeight))

            // Comment
            draw(item.3, at: CGPoint(x: pad, y: barY + barHeight + 6 * s), font: cmtFont, color: valColor.withAlphaComponent(0.7), gc: gc)

            y += rowSpacing
        }

        // Footer
        y = totalHeight - 50 * s
        let footerFont = UIFont.monospacedSystemFont(ofSize: 16 * s, weight: .medium)
        let footer = isEnglish ? "Symmetry Check — Real-time Analysis" : "シンメトリーチェック"
        draw(footer, at: CGPoint(x: pad, y: y), font: footerFont, color: UIColor.cyan.withAlphaComponent(0.4), gc: gc)
    }

    // MARK: - Landmarks on Photo

    private static func drawLandmarksOnPhoto(gc: CGContext, landmarks: VNFaceLandmarks2D, boundingBox: CGRect, photoOrigin: CGPoint, photoSize: CGSize) {
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
        ]

        for (region, color) in regions {
            guard let region = region else { continue }
            let points = FaceAnalyzer.pointsArray(region)
            gc.setFillColor(color.cgColor)

            for point in points {
                let x = photoOrigin.x + (boundingBox.origin.x + point.x * boundingBox.width) * photoSize.width
                let y = (1 - (boundingBox.origin.y + point.y * boundingBox.height)) * photoSize.height
                gc.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
            }
        }
    }

    private static func drawCenterLineOnPhoto(gc: CGContext, landmarks: VNFaceLandmarks2D?, boundingBox: CGRect, photoOrigin: CGPoint, photoSize: CGSize) {
        guard let median = landmarks?.medianLine else { return }
        let points = FaceAnalyzer.pointsArray(median)
        guard points.count >= 2 else { return }

        gc.setStrokeColor(UIColor.orange.withAlphaComponent(0.8).cgColor)
        gc.setLineWidth(1.5)
        gc.setLineDash(phase: 0, lengths: [6, 4])

        let first = points.first!
        gc.move(to: CGPoint(
            x: photoOrigin.x + (boundingBox.origin.x + first.x * boundingBox.width) * photoSize.width,
            y: (1 - (boundingBox.origin.y + first.y * boundingBox.height)) * photoSize.height
        ))

        for i in 1..<points.count {
            gc.addLine(to: CGPoint(
                x: photoOrigin.x + (boundingBox.origin.x + points[i].x * boundingBox.width) * photoSize.width,
                y: (1 - (boundingBox.origin.y + points[i].y * boundingBox.height)) * photoSize.height
            ))
        }
        gc.strokePath()
        gc.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Helpers

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, gc: CGContext) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attr)
    }

    private static func drawDivider(gc: CGContext, y: CGFloat, x1: CGFloat, x2: CGFloat) {
        gc.setStrokeColor(UIColor.cyan.withAlphaComponent(0.3).cgColor)
        gc.setLineWidth(1)
        gc.move(to: CGPoint(x: x1, y: y))
        gc.addLine(to: CGPoint(x: x2, y: y))
        gc.strokePath()
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
