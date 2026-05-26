import Vision
import CoreGraphics

enum FaceAnalyzer {

    static func analyze(landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> SymmetryResult {
        var result = SymmetryResult()
        result.landmarks = landmarks
        result.boundingBox = boundingBox

        // Face center line from nose
        let noseLine = centerLine(from: landmarks.nose, medianLine: landmarks.medianLine)

        result.eyeBalance = measurePairBalance(
            left: landmarks.leftEye,
            right: landmarks.rightEye,
            center: noseLine
        )

        result.eyebrowBalance = measurePairBalance(
            left: landmarks.leftEyebrow,
            right: landmarks.rightEyebrow,
            center: noseLine
        )

        result.mouthBalance = measureMouthBalance(
            outerLips: landmarks.outerLips,
            innerLips: landmarks.innerLips,
            center: noseLine
        )

        result.noseStraightness = measureNoseStraightness(
            nose: landmarks.nose,
            noseCrest: landmarks.noseCrest,
            medianLine: landmarks.medianLine
        )

        result.jawBalance = measureJawBalance(
            faceContour: landmarks.faceContour,
            center: noseLine
        )

        result.overall = [
            result.eyeBalance * 0.25,
            result.eyebrowBalance * 0.15,
            result.noseStraightness * 0.20,
            result.mouthBalance * 0.20,
            result.jawBalance * 0.20,
        ].reduce(0, +)

        return result
    }

    // MARK: - Center Line

    private static func centerLine(from nose: VNFaceLandmarkRegion2D?, medianLine: VNFaceLandmarkRegion2D?) -> CGFloat {
        if let median = medianLine, median.pointCount > 0 {
            let points = pointsArray(median)
            let avgX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            return avgX
        }
        if let nose = nose, nose.pointCount > 0 {
            let points = pointsArray(nose)
            let avgX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            return avgX
        }
        return 0.5
    }

    // MARK: - Pair Balance (eyes, eyebrows)

    private static func measurePairBalance(
        left: VNFaceLandmarkRegion2D?,
        right: VNFaceLandmarkRegion2D?,
        center: CGFloat
    ) -> Double {
        guard let left = left, let right = right,
              left.pointCount > 0, right.pointCount > 0 else { return 50 }

        let leftPts = pointsArray(left)
        let rightPts = pointsArray(right)

        let leftCenter = centroid(leftPts)
        let rightCenter = centroid(rightPts)

        // Distance from center line
        let leftDist = abs(leftCenter.x - center)
        let rightDist = abs(rightCenter.x - center)

        let distRatio = min(leftDist, rightDist) / max(leftDist, rightDist + 0.0001)

        // Height difference
        let heightDiff = abs(leftCenter.y - rightCenter.y)
        let heightScore = max(0, 1.0 - heightDiff * 10)

        // Size comparison
        let leftSize = regionSize(leftPts)
        let rightSize = regionSize(rightPts)
        let sizeRatio = min(leftSize, rightSize) / max(leftSize, rightSize + 0.0001)

        let score = (distRatio * 0.4 + heightScore * 0.35 + sizeRatio * 0.25) * 100
        return min(100, max(0, score))
    }

    // MARK: - Mouth Balance

    private static func measureMouthBalance(
        outerLips: VNFaceLandmarkRegion2D?,
        innerLips: VNFaceLandmarkRegion2D?,
        center: CGFloat
    ) -> Double {
        guard let lips = outerLips, lips.pointCount > 0 else { return 50 }

        let points = pointsArray(lips)
        let mouthCenter = centroid(points)

        // Horizontal center offset
        let centerOffset = abs(mouthCenter.x - center)
        let centerScore = max(0, 1.0 - centerOffset * 8)

        // Left-right width balance
        let leftPoints = points.filter { $0.x < center }
        let rightPoints = points.filter { $0.x >= center }

        let leftWidth = leftPoints.isEmpty ? 0 : abs(leftPoints.map(\.x).min()! - center)
        let rightWidth = rightPoints.isEmpty ? 0 : abs(rightPoints.map(\.x).max()! - center)

        let widthRatio = min(leftWidth, rightWidth) / max(leftWidth, rightWidth + 0.0001)

        // Corner height balance
        let leftCornerY = points.first?.y ?? 0
        let rightCornerY = points.count > 6 ? points[points.count / 2].y : leftCornerY
        let cornerDiff = abs(leftCornerY - rightCornerY)
        let cornerScore = max(0, 1.0 - cornerDiff * 15)

        let score = (centerScore * 0.3 + widthRatio * 0.4 + cornerScore * 0.3) * 100
        return min(100, max(0, score))
    }

    // MARK: - Nose Straightness

    private static func measureNoseStraightness(
        nose: VNFaceLandmarkRegion2D?,
        noseCrest: VNFaceLandmarkRegion2D?,
        medianLine: VNFaceLandmarkRegion2D?
    ) -> Double {
        guard let nose = nose, nose.pointCount > 1 else { return 50 }

        let points = pointsArray(nose)
        let top = points.first!
        let bottom = points.last!

        // Ideal: straight vertical line
        let horizontalDeviation = abs(top.x - bottom.x)
        let verticalSpan = abs(top.y - bottom.y) + 0.0001

        let straightness = max(0, 1.0 - (horizontalDeviation / verticalSpan) * 3)

        // Check each point's deviation from the line
        var totalDeviation: CGFloat = 0
        let expectedX = { (y: CGFloat) -> CGFloat in
            let t = (y - top.y) / (bottom.y - top.y + 0.0001)
            return top.x + t * (bottom.x - top.x)
        }

        for point in points {
            totalDeviation += abs(point.x - expectedX(point.y))
        }
        let avgDeviation = totalDeviation / CGFloat(points.count)
        let deviationScore = max(0, 1.0 - avgDeviation * 20)

        let score = (straightness * 0.5 + deviationScore * 0.5) * 100
        return min(100, max(0, score))
    }

    // MARK: - Jaw Balance

    private static func measureJawBalance(
        faceContour: VNFaceLandmarkRegion2D?,
        center: CGFloat
    ) -> Double {
        guard let contour = faceContour, contour.pointCount > 4 else { return 50 }

        let points = pointsArray(contour)
        let count = points.count

        // Compare left half and right half mirrored
        var totalDiff: CGFloat = 0
        var pairs = 0

        for i in 0..<count / 2 {
            let leftPoint = points[i]
            let rightPoint = points[count - 1 - i]

            let leftDist = abs(leftPoint.x - center)
            let rightDist = abs(rightPoint.x - center)
            let heightDiff = abs(leftPoint.y - rightPoint.y)

            let distDiff = abs(leftDist - rightDist)
            totalDiff += distDiff + heightDiff
            pairs += 1
        }

        let avgDiff = totalDiff / CGFloat(max(pairs, 1))
        let score = max(0, 1.0 - avgDiff * 8) * 100
        return min(100, max(0, score))
    }

    // MARK: - Helpers

    static func pointsArray(_ region: VNFaceLandmarkRegion2D) -> [CGPoint] {
        let ptr = region.normalizedPoints
        return (0..<region.pointCount).map { ptr[$0] }
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint {
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let n = CGFloat(points.count)
        return CGPoint(x: sum.x / n, y: sum.y / n)
    }

    private static func regionSize(_ points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return (xs.max()! - xs.min()!) * (ys.max()! - ys.min()!)
    }
}
