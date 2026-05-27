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

    // Direction info for diagnostics
    var eyeSizeDiff: SideDiff = .even       // which eye is larger
    var eyeHeightDiff: SideDiff = .even     // which eye is higher
    var eyebrowHeightDiff: SideDiff = .even // which eyebrow is higher
    var noseDirection: SideDiff = .even      // nose leans which way
    var mouthShift: SideDiff = .even         // mouth shifted which way
    var jawWidthDiff: SideDiff = .even       // which jaw side is wider

    enum SideDiff {
        case left, right, even
    }

    func eyeComment(isEnglish: Bool) -> String {
        if eyeBalance >= 90 { return isEnglish ? "Nearly identical" : "ほぼ均等" }
        switch eyeSizeDiff {
        case .left:  return isEnglish ? "Left eye slightly larger" : "左目がやや大きい"
        case .right: return isEnglish ? "Right eye slightly larger" : "右目がやや大きい"
        case .even:  return isEnglish ? "Balanced" : "均等"
        }
    }

    func eyebrowComment(isEnglish: Bool) -> String {
        if eyebrowBalance >= 90 { return isEnglish ? "Nearly identical" : "ほぼ均等" }
        switch eyebrowHeightDiff {
        case .left:  return isEnglish ? "Left eyebrow slightly higher" : "左眉がやや高い"
        case .right: return isEnglish ? "Right eyebrow slightly higher" : "右眉がやや高い"
        case .even:  return isEnglish ? "Balanced" : "均等"
        }
    }

    func noseComment(isEnglish: Bool) -> String {
        if noseStraightness >= 90 { return isEnglish ? "Nearly straight" : "ほぼ直線" }
        switch noseDirection {
        case .left:  return isEnglish ? "Slightly tilted left" : "やや左に傾き"
        case .right: return isEnglish ? "Slightly tilted right" : "やや右に傾き"
        case .even:  return isEnglish ? "Straight" : "直線的"
        }
    }

    func mouthComment(isEnglish: Bool) -> String {
        if mouthBalance >= 90 { return isEnglish ? "Well centered" : "ほぼ中央" }
        switch mouthShift {
        case .left:  return isEnglish ? "Slightly shifted left" : "やや左に寄り"
        case .right: return isEnglish ? "Slightly shifted right" : "やや右に寄り"
        case .even:  return isEnglish ? "Centered" : "中央"
        }
    }

    func jawComment(isEnglish: Bool) -> String {
        if jawBalance >= 90 { return isEnglish ? "Nearly symmetrical" : "ほぼ均等" }
        switch jawWidthDiff {
        case .left:  return isEnglish ? "Left jaw slightly wider" : "左顎がやや広い"
        case .right: return isEnglish ? "Right jaw slightly wider" : "右顎がやや広い"
        case .even:  return isEnglish ? "Balanced" : "均等"
        }
    }

    func overallComment(isEnglish: Bool) -> String {
        switch overall {
        case 95...: return isEnglish ? "Exceptional symmetry" : "驚異的な対称性"
        case 90..<95: return isEnglish ? "Very high symmetry" : "非常に高い対称性"
        case 85..<90: return isEnglish ? "Above average symmetry" : "平均以上の対称性"
        case 80..<85: return isEnglish ? "Good symmetry" : "良好な対称性"
        case 70..<80: return isEnglish ? "Average symmetry" : "平均的な対称性"
        case 60..<70: return isEnglish ? "Slight asymmetry" : "やや非対称"
        default:      return isEnglish ? "Notable asymmetry" : "非対称が目立つ"
        }
    }
}
