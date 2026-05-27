import SwiftUI
import Vision

struct ContentView: View {
    @State private var camera = CameraManager()
    @State private var savedImage: UIImage?
    @State private var showSaved = false
    @State private var showResult = false

    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            if let result = camera.currentResult {
                FaceOverlay(result: result, isEnglish: isEnglish)
                    .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                if let result = camera.currentResult {
                    dataPanel(result)
                }
                bottomBar
            }
            .safeAreaPadding()
        }
        .preferredColorScheme(.dark)
        .task { camera.start() }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showResult) {
            if let img = savedImage {
                ResultView(image: img)
            }
        }
        .overlay {
            if showSaved {
                savedToast
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEnglish ? "SYMMETRY CHECK" : "シンメトリーチェック")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Text(isEnglish ? "Facial Symmetry Analyzer" : "顔面対称性分析システム")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.6))
            }

            Spacer()

            if camera.currentResult != nil {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("TRACKING")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text(isEnglish ? "NO FACE" : "顔未検出")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
            }
        }
    }

    private func dataPanel(_ result: SymmetryResult) -> some View {
        VStack(spacing: 0) {
            // Overall score header - compact
            HStack {
                Text(isEnglish ? "OVERALL" : "総合")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))
                Spacer()
                Text(gradeFor(result.overall))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(result.overall))
                Text(String(format: "%.1f%%", result.overall))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(result.overall))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.7))

            Divider().overlay(.cyan.opacity(0.3))

            // Detail metrics - compact, no comments in live view
            VStack(spacing: 2) {
                metricRow(isEnglish ? "Eye" : "目", result.eyeBalance, .green)
                metricRow(isEnglish ? "Brow" : "眉", result.eyebrowBalance, .yellow)
                metricRow(isEnglish ? "Nose" : "鼻", result.noseStraightness, .cyan)
                metricRow(isEnglish ? "Mouth" : "口", result.mouthBalance, .pink)
                metricRow(isEnglish ? "Jaw" : "輪郭", result.jawBalance, .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.cyan.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 40)
        .padding(.bottom, 6)
    }

    private func metricRow(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForScore(value))
                        .frame(width: geo.size.width * min(value / 100, 1), height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f", value))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(colorForScore(value))
                .frame(width: 24, alignment: .trailing)

            Text(gradeFor(value))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(colorForScore(value))
                .frame(width: 20, alignment: .trailing)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 40) {
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.15), in: Circle())
            }

            Button {
                captureAndSave()
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 70, height: 70)
                    Circle().fill(.white).frame(width: 58, height: 58)
                    if camera.isCapturing {
                        ProgressView().tint(.black)
                    }
                }
            }
            .disabled(camera.isCapturing || camera.currentResult == nil)
            .opacity(camera.currentResult == nil ? 0.4 : 1)

            Button {
                if savedImage != nil {
                    showResult = true
                }
            } label: {
                if let img = savedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
            }
        }
        .padding(.bottom, 10)
    }

    private var savedToast: some View {
        VStack {
            Spacer()
            Text(isEnglish ? "Saved to Photos" : "写真に保存しました")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.green.opacity(0.8), in: Capsule())
                .padding(.bottom, 120)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showSaved)
    }

    private func captureAndSave() {
        guard camera.currentResult != nil else { return }
        camera.capturePhoto { photo in
            guard let photo = photo else { return }
            // Re-analyze the captured photo for accurate coordinates
            let normalized = Self.normalizeOrientation(photo)
            let freshResult = Self.analyzePhoto(normalized)
            let resultToUse = freshResult ?? camera.currentResult!
            let composed = PhotoComposer.compose(photo: normalized, result: resultToUse, isEnglish: isEnglish)
            savedImage = composed
            UIImageWriteToSavedPhotosAlbum(composed, nil, nil, nil)
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSaved = false
            }
        }
    }

    private static func analyzePhoto(_ image: UIImage) -> SymmetryResult? {
        // Normalize orientation so cgImage matches the visual layout
        let normalized = normalizeOrientation(image)
        guard let cgImage = normalized.cgImage else { return nil }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let results = request.results,
              let face = results.first,
              let landmarks = face.landmarks else { return nil }
        return FaceAnalyzer.analyze(landmarks: landmarks, boundingBox: face.boundingBox)
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func gradeFor(_ score: Double) -> String {
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

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 90...: return Color(red: 0.3, green: 1, blue: 0.5)
        case 80..<90: return Color(red: 0.5, green: 1, blue: 0.8)
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return Color(red: 1, green: 0.4, blue: 0.4)
        }
    }
}

// MARK: - Face Overlay (real-time landmarks on camera)

struct FaceOverlay: View {
    let result: SymmetryResult
    let isEnglish: Bool

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard let landmarks = result.landmarks else { return }
                let box = result.boundingBox
                let faceRect = CGRect(
                    x: box.origin.x * size.width,
                    y: (1 - box.origin.y - box.height) * size.height,
                    width: box.width * size.width,
                    height: box.height * size.height
                )

                // Face bounding box
                ctx.stroke(Path(faceRect), with: .color(.cyan.opacity(0.5)), lineWidth: 1)

                // Corner brackets
                drawCornerBrackets(ctx: &ctx, rect: faceRect)

                // Landmarks
                let regions: [(VNFaceLandmarkRegion2D?, Color)] = [
                    (landmarks.leftEye, .green),
                    (landmarks.rightEye, .green),
                    (landmarks.leftEyebrow, .yellow),
                    (landmarks.rightEyebrow, .yellow),
                    (landmarks.nose, .cyan),
                    (landmarks.noseCrest, .cyan),
                    (landmarks.outerLips, .pink),
                    (landmarks.innerLips, .pink),
                    (landmarks.faceContour, .white.opacity(0.5)),
                    (landmarks.leftPupil, .red),
                    (landmarks.rightPupil, .red),
                ]

                for (region, color) in regions {
                    guard let region = region else { continue }
                    let points = FaceAnalyzer.pointsArray(region)
                    for point in points {
                        let x = (box.origin.x + point.x * box.width) * size.width
                        let y = (1 - (box.origin.y + point.y * box.height)) * size.height
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(color))
                    }
                }

                // Center line (median)
                if let median = landmarks.medianLine {
                    let pts = FaceAnalyzer.pointsArray(median)
                    if pts.count >= 2 {
                        var path = Path()
                        let first = pts[0]
                        path.move(to: CGPoint(
                            x: (box.origin.x + first.x * box.width) * size.width,
                            y: (1 - (box.origin.y + first.y * box.height)) * size.height
                        ))
                        for i in 1..<pts.count {
                            path.addLine(to: CGPoint(
                                x: (box.origin.x + pts[i].x * box.width) * size.width,
                                y: (1 - (box.origin.y + pts[i].y * box.height)) * size.height
                            ))
                        }
                        ctx.stroke(path, with: .color(.orange.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }
            }
        }
    }

    private func drawCornerBrackets(ctx: inout GraphicsContext, rect: CGRect) {
        let len: CGFloat = 14
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + len), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + len, y: rect.minY)),
            (CGPoint(x: rect.maxX - len, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + len)),
            (CGPoint(x: rect.maxX, y: rect.maxY - len), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - len, y: rect.maxY)),
            (CGPoint(x: rect.minX + len, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - len)),
        ]
        for (p1, p2, p3) in corners {
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)
            ctx.stroke(path, with: .color(.cyan), lineWidth: 2)
        }
    }
}

// MARK: - Result View (saved photo preview)

struct ResultView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle(isEnglish ? "Analysis Result" : "分析結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEnglish ? "Close" : "閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("Symmetry Check", image: Image(uiImage: image)))
                }
            }
        }
    }
}
