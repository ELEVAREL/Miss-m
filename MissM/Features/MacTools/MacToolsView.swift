import SwiftUI
import AppKit
import PDFKit
import Vision

// MARK: - Mac Tools View (Phase 5)
// PDF Reader + Screenshot OCR hub

struct MacToolsView: View {
    let claudeService: ClaudeService
    @State private var selectedFeature: MacToolFeature? = nil

    enum MacToolFeature: String, CaseIterable {
        case pdfReader = "PDF Reader"
        case screenshotOCR = "Screenshot OCR"

        var icon: String {
            switch self {
            case .pdfReader: return "📄"
            case .screenshotOCR: return "📸"
            }
        }

        var description: String {
            switch self {
            case .pdfReader: return "Read & summarise PDFs"
            case .screenshotOCR: return "OCR any screen region"
            }
        }
    }

    var body: some View {
        if let feature = selectedFeature {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { selectedFeature = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Tools")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                featureView(for: feature)
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MAC TOOLS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Power Tools")
                            .font(.custom("PlayfairDisplay-Italic", size: 20))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(MacToolFeature.allCases, id: \.self) { feature in
                            Button(action: { selectedFeature = feature }) {
                                VStack(spacing: 8) {
                                    Text(feature.icon)
                                        .font(.system(size: 24))
                                    Text(feature.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(feature.description)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textSoft)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .glassCard(padding: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func featureView(for feature: MacToolFeature) -> some View {
        switch feature {
        case .pdfReader: PDFDropZoneView(claudeService: claudeService)
        case .screenshotOCR: ScreenshotOCRView(claudeService: claudeService)
        }
    }
}

// MARK: - PDF Drop Zone View

struct PDFDropZoneView: View {
    let claudeService: ClaudeService
    @State private var extractedText: String = ""
    @State private var aiSummary: String = ""
    @State private var fileName: String = ""
    @State private var pageCount: Int = 0
    @State private var isExtracting = false
    @State private var isSummarising = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("PDF READER")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Drop zone / file picker
                if extractedText.isEmpty && !isExtracting {
                    Button(action: { openPDFPicker() }) {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.Colors.roseMid)
                            Text("Select a PDF")
                                .font(.custom("PlayfairDisplay-Italic", size: 16))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            Text("Choose a file to extract text and get an AI summary")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .glassCard(padding: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                .foregroundColor(Theme.Colors.roseLight)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                // Extracting state
                if isExtracting {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Extracting text...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Error
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMedium)
                    }
                    .padding(10)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // File info + extracted text
                if !extractedText.isEmpty {
                    // File info card
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Text("\(pageCount) page\(pageCount == 1 ? "" : "s") · \(extractedText.count) characters")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        Spacer()
                        Button(action: { resetState() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.textXSoft)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

                    // Summarise button
                    if aiSummary.isEmpty && !isSummarising {
                        Button(action: { Task { await summarisePDF() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("AI Summary")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }

                    // Summarising state
                    if isSummarising {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text("Summarising with Claude...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .padding(10)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // AI Summary card
                    if !aiSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("AI SUMMARY")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiSummary, forType: .string)
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(aiSummary)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // Extracted text preview
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("EXTRACTED TEXT")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(extractedText, forType: .string)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy All")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(extractedText.prefix(2000) + (extractedText.count > 2000 ? "\n\n... (\(extractedText.count - 2000) more characters)" : ""))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMedium)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func openPDFPicker() {
        let panel = NSOpenPanel()
        panel.title = "Select a PDF"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExtracting = true
        errorMessage = nil
        fileName = url.lastPathComponent

        Task {
            await extractPDFText(from: url)
        }
    }

    private func extractPDFText(from url: URL) async {
        defer { isExtracting = false }

        guard let pdfDocument = PDFDocument(url: url) else {
            errorMessage = "Could not open PDF — the file may be corrupted or encrypted."
            return
        }

        pageCount = pdfDocument.pageCount
        var allText = ""

        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                allText += pageText + "\n\n"
            }
        }

        let trimmed = allText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // PDFKit couldn't extract text — try Vision OCR on each page
            allText = await ocrPDFPages(document: pdfDocument)
        }

        if allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "No text could be extracted — this PDF may be image-only without selectable text."
            return
        }

        extractedText = allText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ocrPDFPages(document: PDFDocument) async -> String {
        var result = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let renderer = NSImage(size: bounds.size)
            renderer.lockFocus()
            if let context = NSGraphicsContext.current?.cgContext {
                context.setFillColor(.white)
                context.fill(bounds)
                page.draw(with: .mediaBox, to: context)
            }
            renderer.unlockFocus()

            guard let tiffData = renderer.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let cgImage = bitmap.cgImage else { continue }

            let pageText = await recognizeText(in: cgImage)
            if !pageText.isEmpty {
                result += pageText + "\n\n"
            }
        }
        return result
    }

    private func recognizeText(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private func summarisePDF() async {
        isSummarising = true
        defer { isSummarising = false }

        // Send first ~4000 chars to stay within token budget
        let textToSummarise = String(extractedText.prefix(4000))
        let prompt = """
        Summarise this PDF document for a busy university student. \
        Provide a clear, structured summary with key points. \
        Keep it concise — bullet points are fine. \
        Document title: \(fileName)

        Text:
        \(textToSummarise)
        """

        do {
            aiSummary = try await claudeService.ask(prompt)
        } catch {
            aiSummary = "Sorry, couldn't generate a summary right now. Please try again."
        }
    }

    private func resetState() {
        extractedText = ""
        aiSummary = ""
        fileName = ""
        pageCount = 0
        errorMessage = nil
    }
}

// MARK: - Screenshot OCR View

struct ScreenshotOCRView: View {
    let claudeService: ClaudeService
    @State private var recognizedText: String = ""
    @State private var aiExplanation: String = ""
    @State private var isCapturing = false
    @State private var isRecognizing = false
    @State private var isExplaining = false
    @State private var errorMessage: String? = nil
    @State private var capturedImage: NSImage? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("SCREENSHOT OCR")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Capture button
                if recognizedText.isEmpty && !isRecognizing && !isCapturing {
                    VStack(spacing: 14) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.roseMid)
                        Text("Capture Screen")
                            .font(.custom("PlayfairDisplay-Italic", size: 16))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        Text("Select a region of your screen to extract text with AI")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button(action: { captureScreenRegion() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.viewfinder")
                                Text("Select Region")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())

                        // Or pick from file
                        Button(action: { openImagePicker() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                Text("Open Image File")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassCard(padding: 14)
                    .padding(.horizontal, 16)
                }

                // Processing state
                if isCapturing || isRecognizing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(isCapturing ? "Capturing..." : "Recognizing text...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Error
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMedium)
                    }
                    .padding(10)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Results
                if !recognizedText.isEmpty {
                    // Image preview (if available)
                    if let image = capturedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(Theme.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Theme.Colors.roseLight, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                    }

                    // Recognized text
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RECOGNIZED TEXT")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(recognizedText, forType: .string)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(recognizedText)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

                    // AI Explain button
                    if aiExplanation.isEmpty && !isExplaining {
                        Button(action: { Task { await explainText() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("AI Explain")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }

                    // Explaining state
                    if isExplaining {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text("Asking Claude...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .padding(10)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // AI Explanation
                    if !aiExplanation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("AI EXPLANATION")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiExplanation, forType: .string)
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(aiExplanation)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        Button(action: { resetState() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("New Capture")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func captureScreenRegion() {
        isCapturing = true
        errorMessage = nil

        // Use macOS screencapture tool in interactive mode
        let task = Process()
        let tempPath = NSTemporaryDirectory() + "missm_screenshot_\(UUID().uuidString).png"
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-s", tempPath]

        Task {
            do {
                try task.run()
                task.waitUntilExit()

                await MainActor.run {
                    isCapturing = false
                }

                let fileURL = URL(fileURLWithPath: tempPath)
                guard FileManager.default.fileExists(atPath: tempPath),
                      let image = NSImage(contentsOf: fileURL) else {
                    await MainActor.run {
                        errorMessage = "Capture cancelled or failed — try again."
                    }
                    return
                }

                await MainActor.run {
                    capturedImage = image
                }

                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let cgImage = bitmap.cgImage else {
                    await MainActor.run {
                        errorMessage = "Could not process screenshot image."
                    }
                    return
                }

                await performOCR(on: cgImage)

                // Clean up temp file
                try? FileManager.default.removeItem(at: fileURL)

            } catch {
                await MainActor.run {
                    isCapturing = false
                    errorMessage = "Screenshot capture failed — check Screen Recording permission in System Settings."
                }
            }
        }
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select an Image"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Could not open image file."
            return
        }

        capturedImage = image
        errorMessage = nil

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            errorMessage = "Could not process image."
            return
        }

        Task {
            await performOCR(on: cgImage)
        }
    }

    private func performOCR(on cgImage: CGImage) async {
        await MainActor.run { isRecognizing = true }

        let text = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }

        await MainActor.run {
            isRecognizing = false
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "No text found in this image — try a clearer region with visible text."
            } else {
                recognizedText = text
            }
        }
    }

    private func explainText() async {
        isExplaining = true
        defer { isExplaining = false }

        let textToExplain = String(recognizedText.prefix(3000))
        let prompt = """
        The user captured a screenshot and OCR extracted this text. \
        Explain what this text is about in a helpful way. \
        If it looks like lecture notes, a formula, code, or an error message, \
        explain it clearly for a university student. Be concise.

        Text:
        \(textToExplain)
        """

        do {
            aiExplanation = try await claudeService.ask(prompt)
        } catch {
            aiExplanation = "Sorry, couldn't explain this text right now. Please try again."
        }
    }

    private func resetState() {
        recognizedText = ""
        aiExplanation = ""
        capturedImage = nil
        errorMessage = nil
    }
}
