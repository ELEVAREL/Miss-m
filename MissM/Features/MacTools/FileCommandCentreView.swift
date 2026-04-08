import SwiftUI
import AppKit
import PDFKit
import Vision

// MARK: - File Command Centre View (Phase 5)
// Drag any file → AI reads/summarises/generates study content

struct FileCommandCentreView: View {
    let claudeService: ClaudeService
    @State private var fileName: String = ""
    @State private var fileType: String = ""
    @State private var fileSize: String = ""
    @State private var extractedText: String = ""
    @State private var aiResult: String = ""
    @State private var isProcessing = false
    @State private var isSummarising = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Text("FILE COMMAND CENTRE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Rectangle()
                        .fill(Theme.Colors.rosePrimary.opacity(0.14))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)

                // Drop zone
                if extractedText.isEmpty && !isProcessing {
                    Button(action: { openFilePicker() }) {
                        VStack(spacing: 12) {
                            Text("📁")
                                .font(.system(size: 48))

                            Text("Drop any file here")
                                .font(.custom("PlayfairDisplay-Italic", size: 18))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("Miss M AI reads PDFs, text files, images — extracts text and generates study content")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSoft)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                            HStack(spacing: 7) {
                                ForEach(["PDF", "TXT", "RTF", "Images"], id: \.self) { type in
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
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.4))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [10, 6]))
                                .foregroundColor(Theme.Colors.rosePrimary.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                // Processing
                if isProcessing {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Text("📁")
                                    .font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text("\(fileType) · \(fileSize)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                            Text("Reading file…")
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

                // Results
                if !extractedText.isEmpty {
                    // File info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Text(fileTypeIcon)
                                .font(.system(size: 22))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Text("\(fileType) · \(fileSize) · \(extractedText.count) chars")
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

                    // AI Actions
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        FileActionCard(icon: "📝", name: "Summarise") {
                            Task { await summariseFile(prompt: "Summarise this document concisely for a university student. Use bullet points.") }
                        }
                        FileActionCard(icon: "🃏", name: "Flashcards") {
                            Task { await summariseFile(prompt: "Generate 5 flashcards from this content. Format: Q: [question] / A: [answer]") }
                        }
                        FileActionCard(icon: "🔍", name: "Key Points") {
                            Task { await summariseFile(prompt: "Extract the 5 most important key points from this document.") }
                        }
                        FileActionCard(icon: "📋", name: "Outline") {
                            Task { await summariseFile(prompt: "Create a structured outline from this document with main headings and subpoints.") }
                        }
                    }
                    .padding(.horizontal, 16)

                    // AI Result
                    if isSummarising {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text("Processing with Claude…")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .padding(10)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    if !aiResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("✦ AI RESULT")
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiResult, forType: .string)
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

                            Text(aiResult)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textMedium)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.rosePrimary.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var fileTypeIcon: String {
        switch fileType.lowercased() {
        case "pdf": return "📄"
        case "txt", "rtf": return "📝"
        case "png", "jpg", "jpeg", "tiff": return "🖼"
        default: return "📁"
        }
    }

    // MARK: - File Picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select a File"
        panel.allowedContentTypes = [.pdf, .plainText, .rtf, .png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isProcessing = true
        errorMessage = nil
        fileName = url.lastPathComponent
        fileType = url.pathExtension.uppercased()

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let mb = Double(size) / 1_048_576
            fileSize = mb >= 1.0 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", Double(size) / 1024)
        }

        Task { await extractText(from: url) }
    }

    private func extractText(from url: URL) async {
        defer { isProcessing = false }

        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let doc = PDFDocument(url: url) else {
                errorMessage = "Could not open PDF."
                return
            }
            var text = ""
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i), let pageText = page.string {
                    text += pageText + "\n\n"
                }
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "No text extracted — this file may be image-only."
                return
            }
            extractedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        } else if ext == "txt" || ext == "rtf" {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errorMessage = "File is empty."
                    return
                }
                extractedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                errorMessage = "Could not read text file."
            }

        } else if ["png", "jpg", "jpeg", "tiff"].contains(ext) {
            guard let image = NSImage(contentsOf: url),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let cgImage = bitmap.cgImage else {
                errorMessage = "Could not open image."
                return
            }

            let text = await ocrImage(cgImage)
            if text.isEmpty {
                errorMessage = "No text found in image."
                return
            }
            extractedText = text

        } else {
            errorMessage = "Unsupported file type."
        }
    }

    private func ocrImage(_ cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
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
    }

    private func summariseFile(prompt: String) async {
        isSummarising = true
        defer { isSummarising = false }

        let textToProcess = String(extractedText.prefix(4000))
        let fullPrompt = """
        \(prompt)

        File: \(fileName)

        Content:
        \(textToProcess)
        """

        do {
            aiResult = try await claudeService.ask(fullPrompt)
        } catch {
            aiResult = "Sorry, couldn't process this file right now."
        }
    }

    private func resetState() {
        fileName = ""
        fileType = ""
        fileSize = ""
        extractedText = ""
        aiResult = ""
        errorMessage = nil
    }
}

// MARK: - File Action Card
struct FileActionCard: View {
    let icon: String
    let name: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white : Color.white.opacity(0.8))
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: isHovered ? Theme.Colors.shadow : .clear, radius: 12, x: 0, y: 4)
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
