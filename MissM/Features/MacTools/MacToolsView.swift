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
        case safariCompanion = "Safari Companion"
        case fileCommandCentre = "File Command Centre"

        var icon: String {
            switch self {
            case .pdfReader: return "📄"
            case .screenshotOCR: return "📸"
            case .safariCompanion: return "🌐"
            case .fileCommandCentre: return "📁"
            }
        }

        var description: String {
            switch self {
            case .pdfReader: return "Read & summarise PDFs"
            case .screenshotOCR: return "OCR any screen region"
            case .safariCompanion: return "Read current Safari page"
            case .fileCommandCentre: return "AI reads any file"
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
                            MacToolCard(feature: feature) {
                                selectedFeature = feature
                            }
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
        case .safariCompanion: SafariCompanionView(claudeService: claudeService)
        case .fileCommandCentre: FileCommandCentreView(claudeService: claudeService)
        }
    }
}

// MARK: - Mac Tool Card (per design: hover translateY)
struct MacToolCard: View {
    let feature: MacToolsView.MacToolFeature
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(feature.icon)
                    .font(.system(size: 26))
                Text(feature.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(feature.description)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(isHovered ? Color.white : Theme.Colors.glassWhite)
            .cornerRadius(Theme.Radius.md)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(isHovered ? Theme.Colors.roseLight : Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: Theme.Colors.shadow, radius: isHovered ? 16 : 10, x: 0, y: isHovered ? 6 : 4)
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PDF Drop Zone View

struct PDFDropZoneView: View {
    let claudeService: ClaudeService
    @State private var extractedText: String = ""
    @State private var aiSummary: String = ""
    @State private var fileName: String = ""
    @State private var pageCount: Int = 0
    @State private var fileSize: String = ""
    @State private var isExtracting = false
    @State private var isSummarising = false
    @State private var errorMessage: String? = nil
    @State private var isDragHovered = false

    private let fileTypes = ["PDF", "DOCX", "TXT", "PPTX", "Images"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header (per design: plbl with line)
                HStack(spacing: 8) {
                    Text("PDF DROP ZONE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Rectangle()
                        .fill(Theme.Colors.rosePrimary.opacity(0.14))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)

                // Drop zone / file picker (per design: dashed border, file type badges)
                if extractedText.isEmpty && !isExtracting {
                    Button(action: { openPDFPicker() }) {
                        VStack(spacing: 10) {
                            Text("📄")
                                .font(.system(size: 48))

                            Text("Drop your lecture PDF here")
                                .font(.custom("PlayfairDisplay-Italic", size: 18))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("Miss M AI reads it instantly — summaries, flashcards, deadlines, key concepts")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSoft)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                            // File type badges
                            HStack(spacing: 7) {
                                ForEach(fileTypes, id: \.self) { type in
                                    Text(type)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(Theme.Colors.rosePrimary.opacity(0.08))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.rosePrimary.opacity(0.18), lineWidth: 1))
                                        .cornerRadius(8)
                                }
                            }

                            Text("— or —")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textXSoft)

                            Text("Browse Files")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.Gradients.rosePrimary)
                                .cornerRadius(12)
                                .shadow(color: Theme.Colors.rosePrimary.opacity(0.32), radius: 14, x: 0, y: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .padding(.horizontal, 24)
                        .background(isDragHovered ? Theme.Colors.rosePrimary.opacity(0.04) : Color.white.opacity(0.4))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [10, 6]))
                                .foregroundColor(isDragHovered ? Theme.Colors.rosePrimary : Theme.Colors.rosePrimary.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                // Processing state (per design: file icon, name, progress bar)
                if isExtracting {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // File icon (per design: 44px, gradient bg)
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Text("📄")
                                    .font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(fileSize)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.rosePrimary.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [Theme.Colors.rosePrimary, Theme.Colors.roseMid], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * 0.75)
                            }
                        }
                        .frame(height: 4)

                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            Text("Miss M AI is reading your PDF…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.82))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.rosePrimary.opacity(0.2), lineWidth: 1))
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

                // AI Actions grid (per design: 2-col, 6 actions)
                if !extractedText.isEmpty {
                    // File info card
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Text("📄")
                                .font(.system(size: 22))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Text("\(pageCount) page\(pageCount == 1 ? "" : "s") · \(extractedText.count) characters")
                                .font(.system(size: 10))
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
                    .padding(14)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

                    // AI Actions (per design: "What should I do with it?")
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Text("WHAT SHOULD I DO WITH IT?")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2.5)
                                .foregroundColor(Theme.Colors.rosePrimary)
                            Rectangle()
                                .fill(Theme.Colors.rosePrimary.opacity(0.14))
                                .frame(height: 1)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            PDFActionCard(icon: "📝", name: "Summarise", desc: "Key points in plain English") {
                                Task { await summarisePDF() }
                            }
                            PDFActionCard(icon: "🃏", name: "Flashcards", desc: "Auto-generate quiz cards") {}
                            PDFActionCard(icon: "📅", name: "Find Deadlines", desc: "Extract dates & tasks") {}
                            PDFActionCard(icon: "✍️", name: "Essay Help", desc: "Use as essay source") {}
                            PDFActionCard(icon: "🔍", name: "Explain Concepts", desc: "Break down hard parts") {}
                            PDFActionCard(icon: "📚", name: "Add Citations", desc: "APA / Harvard refs") {}
                        }
                    }
                    .padding(14)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

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

                    // AI Summary result card (per design: icon header, body, tags)
                    if !aiSummary.isEmpty {
                        PDFResultCard(icon: "📝", iconBg: Theme.Colors.rosePrimary.opacity(0.1),
                                      title: "Summary", subtitle: fileName) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(aiSummary)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textMedium)
                                    .textSelection(.enabled)
                                    .lineSpacing(4)

                                HStack(spacing: 8) {
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(aiSummary, forType: .string)
                                    }) {
                                        Text("Copy to Essay")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Theme.Gradients.rosePrimary)
                                            .cornerRadius(11)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {}) {
                                        Text("Expand")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Theme.Colors.textMedium)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.75))
                                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                                            .cornerRadius(11)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
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

        // Get file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let mb = Double(size) / 1_048_576
            fileSize = mb >= 1.0 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", Double(size) / 1024)
        }

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
        fileSize = ""
        errorMessage = nil
    }
}

// MARK: - PDF Action Card (per design: 2-col grid, hover translateY)
struct PDFActionCard: View {
    let icon: String
    let name: String
    let desc: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 22))
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isHovered ? Color.white : Color.white.opacity(0.8))
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: isHovered ? Theme.Colors.shadow : .clear, radius: 16, x: 0, y: 6)
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PDF Result Card (per design: icon header + body + tags)
struct PDFResultCard<Content: View>: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBg)
                        .frame(width: 32, height: 32)
                    Text(icon)
                        .font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                        .lineLimit(1)
                }
            }
            content()
        }
        .padding(14)
        .background(isHovered ? Color.white : Theme.Colors.glassWhite)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Theme.Colors.shadow, radius: isHovered ? 18 : 10, x: 0, y: isHovered ? 6 : 4)
        .offset(y: isHovered ? -1 : 0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
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
    @State private var selectedMode = 0

    private let captureModes: [(icon: String, name: String, desc: String)] = [
        ("✂️", "Select Area", "Draw a box around any text on screen"),
        ("🖥️", "Full Screen", "Capture and read the entire screen"),
        ("🪟", "Active Window", "Read whatever app is open"),
        ("📷", "From Image", "Read text from any photo or image")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header (per design: Playfair title)
                HStack(spacing: 8) {
                    Text("CAPTURE MODE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Rectangle()
                        .fill(Theme.Colors.rosePrimary.opacity(0.14))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)

                // Capture modes grid (per design: 2x2, selected has rose tint)
                if recognizedText.isEmpty && !isRecognizing && !isCapturing {
                    VStack(spacing: 12) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(0..<captureModes.count, id: \.self) { index in
                                CaptureModeTile(
                                    icon: captureModes[index].icon,
                                    name: captureModes[index].name,
                                    desc: captureModes[index].desc,
                                    isSelected: selectedMode == index
                                ) {
                                    selectedMode = index
                                }
                            }
                        }

                        // Shortcut badge (per design)
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                KeyBadge(key: "⌘")
                                KeyBadge(key: "⇧")
                                KeyBadge(key: "S")
                            }
                            Text("Capture anywhere")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.textMedium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.1), lineWidth: 1))
                        .cornerRadius(8)

                        // Capture button
                        Button(action: {
                            if selectedMode == 3 { openImagePicker() }
                            else { captureScreenRegion() }
                        }) {
                            HStack(spacing: 4) {
                                Text("📸")
                                Text("Capture Now")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.Gradients.rosePrimary)
                            .cornerRadius(12)
                            .shadow(color: Theme.Colors.rosePrimary.opacity(0.32), radius: 14, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Processing state
                if isCapturing || isRecognizing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(isCapturing ? "Capturing..." : "Recognizing text with Vision OCR...")
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
                        VStack(spacing: 0) {
                            // Window chrome (per design: dark preview)
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: "#FF5F57")).frame(width: 10, height: 10)
                                Circle().fill(Color(hex: "#FEBC2E")).frame(width: 10, height: 10)
                                Circle().fill(Color(hex: "#27C93F")).frame(width: 10, height: 10)
                                Spacer()
                                Text("Screenshot Preview")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#2D2D44"))

                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 140)
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "#1A1A2E"))
                        }
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.2), radius: 28, x: 0, y: 8)
                        .padding(.horizontal, 16)
                    }

                    // OCR result (per design: left border, italic text, action buttons)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✦ TEXT EXTRACTED VIA VISION OCR")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textSoft)

                        // Text with left border (per design)
                        Text(recognizedText)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundColor(Theme.Colors.textMedium)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .padding(.leading, 12)
                            .overlay(
                                Rectangle()
                                    .fill(Theme.Colors.roseMid)
                                    .frame(width: 3),
                                alignment: .leading
                            )

                        // Action buttons (per design: Explain, Copy, Citation, Essay)
                        HStack(spacing: 8) {
                            Button(action: { Task { await explainText() } }) {
                                Text("✦ Explain This")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Theme.Gradients.rosePrimary)
                                    .cornerRadius(11)
                                    .shadow(color: Theme.Colors.rosePrimary.opacity(0.3), radius: 12, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)

                            OCRActionButton(label: "📋 Copy Text") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(recognizedText, forType: .string)
                            }
                            OCRActionButton(label: "📚 Add Citation") {}
                            OCRActionButton(label: "✍️ Use in Essay") {}
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.82))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.rosePrimary.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 16)

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

                    // AI Explanation (per design: ai-resp card)
                    if !aiExplanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 7) {
                                Text("✦ AI RESPONSE")
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.rosePrimary)
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
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textMedium)
                                .lineSpacing(4)
                                .textSelection(.enabled)

                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    Text("Add to Essay")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Theme.Gradients.rosePrimary)
                                        .cornerRadius(11)
                                }
                                .buttonStyle(.plain)

                                OCRActionButton(label: "+ Citation") {}
                                OCRActionButton(label: "🃏 Flashcard") {}
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.rosePrimary.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // New capture button
                    Button(action: { resetState() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("New Capture")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
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

// MARK: - Capture Mode Tile (per design: 2x2 grid, selected has rose tint)
struct CaptureModeTile: View {
    let icon: String
    let name: String
    let desc: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 26))
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                isSelected
                    ? LinearGradient(colors: [Theme.Colors.rosePrimary.opacity(0.08), Theme.Colors.roseDeep.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.Colors.rosePrimary.opacity(0.3) : Theme.Colors.glassBorder, lineWidth: 1.5)
            )
            .shadow(color: isHovered ? Theme.Colors.shadow : .clear, radius: 18, x: 0, y: 6)
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Key Badge (per design: keyboard shortcut display)
struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Theme.Colors.textMedium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.15), lineWidth: 1))
            .cornerRadius(5)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - OCR Action Button (per design: ghost button style)
struct OCRActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                .cornerRadius(11)
        }
        .buttonStyle(.plain)
    }
}
