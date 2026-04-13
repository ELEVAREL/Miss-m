import SwiftUI
import PDFKit
import Vision

// MARK: - PDF Models

struct PDFFileItem: Identifiable {
    let id = UUID()
    var url: URL
    var name: String
    var pageCount: Int
    var extractedText: String = ""
}

enum PDFAction: String, CaseIterable {
    case summarise = "Summarise"
    case flashcards = "Flashcards"
    case deadlines = "Find Deadlines"
    case essayHelp = "Essay Help"
    case explain = "Explain Concepts"
    case citations = "Add Citations"

    var icon: String {
        switch self {
        case .summarise: return "\u{1F4DD}"
        case .flashcards: return "\u{1F0CF}"
        case .deadlines: return "\u{23F0}"
        case .essayHelp: return "\u{270D}\u{FE0F}"
        case .explain: return "\u{1F4A1}"
        case .citations: return "\u{1F4DA}"
        }
    }
}

// MARK: - PDF ViewModel

@Observable
class PDFDropzoneViewModel {
    var files: [PDFFileItem] = []
    var selectedFile: PDFFileItem?
    var isProcessing = false
    var result = ""
    var selectedAction: PDFAction?
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func processFile(url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        var text = ""
        for i in 0..<min(doc.pageCount, 20) {
            if let page = doc.page(at: i) {
                text += page.string ?? ""
                text += "\n"
            }
        }
        let file = PDFFileItem(url: url, name: url.lastPathComponent, pageCount: doc.pageCount, extractedText: text)
        files.insert(file, at: 0)
        selectedFile = file
    }

    func runOCR(on url: URL) async -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var allText = ""
        for i in 0..<min(doc.pageCount, 5) {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let image = NSImage(size: bounds.size)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                page.draw(with: .mediaBox, to: ctx)
            }
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let cgImage = NSBitmapImageRep(data: tiff)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
            if let observations = request.results {
                allText += observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            }
        }
        return allText
    }

    func runAction(_ action: PDFAction) async {
        guard let file = selectedFile else { return }
        isProcessing = true
        selectedAction = action
        let text = file.extractedText.isEmpty ? await runOCR(on: file.url) : file.extractedText
        let truncated = String(text.prefix(3000))

        let prompt: String
        switch action {
        case .summarise:
            prompt = "Summarise this document in 5 bullet points:\n\n\(truncated)"
        case .flashcards:
            prompt = "Create 5 study flashcards (Q: / A: format) from this text:\n\n\(truncated)"
        case .deadlines:
            prompt = "Find all dates, deadlines, and due dates mentioned in this text. List each with context:\n\n\(truncated)"
        case .essayHelp:
            prompt = "Identify the main arguments and suggest an essay outline based on this text:\n\n\(truncated)"
        case .explain:
            prompt = "Explain the key concepts from this text in simple terms for a university student:\n\n\(truncated)"
        case .citations:
            prompt = "Generate Harvard-style citations for the sources and references mentioned in this text:\n\n\(truncated)"
        }

        do {
            result = try await claudeService.ask(prompt)
        } catch {
            result = "Could not process — please try again."
        }
        isProcessing = false
    }
}

// MARK: - PDF Dropzone View

struct PDFDropzoneView: View {
    let claudeService: ClaudeService
    @State private var viewModel: PDFDropzoneViewModel
    @State private var isTargeted = false

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: PDFDropzoneViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("PDF Reader")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Drop Zone
                if viewModel.selectedFile == nil {
                    dropZone
                        .padding(.horizontal, 14)
                } else {
                    selectedFileView
                }

                // Recent Files
                if !viewModel.files.isEmpty && viewModel.selectedFile == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECENT FILES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(viewModel.files) { file in
                            Button(action: { viewModel.selectedFile = file }) {
                                HStack(spacing: 8) {
                                    Text("\u{1F4C4}").font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text("\(file.pageCount) pages")
                                            .font(.system(size: 9))
                                            .foregroundColor(Theme.Colors.textSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textXSoft)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased() == "pdf" else { return }
                DispatchQueue.main.async { viewModel.processFile(url: url) }
            }
            return true
        }
    }

    var dropZone: some View {
        VStack(spacing: 12) {
            Text("\u{1F4C4}")
                .font(.system(size: 36))
            Text("Drop PDF Here")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("or click to browse")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSoft)
            Button("Browse Files") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.pdf]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    viewModel.processFile(url: url)
                }
            }
            .buttonStyle(RoseButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(isTargeted ? Theme.Colors.rosePrimary : Theme.Colors.roseLight)
        )
        .background(isTargeted ? Theme.Colors.rosePale.opacity(0.3) : Color.clear)
        .cornerRadius(16)
    }

    var selectedFileView: some View {
        VStack(spacing: 10) {
            // Back + file info
            HStack {
                Button(action: { viewModel.selectedFile = nil; viewModel.result = "" }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                Spacer()
                if let file = viewModel.selectedFile {
                    Text("\u{1F4C4} \(file.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }
            .padding(.horizontal, 14)

            // AI Actions Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(PDFAction.allCases, id: \.self) { action in
                    Button(action: { Task { await viewModel.runAction(action) } }) {
                        VStack(spacing: 4) {
                            Text(action.icon).font(.system(size: 18))
                            Text(action.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(viewModel.selectedAction == action ? .white : Theme.Colors.textMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedAction == action ? AnyView(Theme.Gradients.rosePrimary) : AnyView(Color.white.opacity(0.6)))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                }
            }
            .padding(.horizontal, 14)

            // Result
            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6)
                    Text("Reading PDF...")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
            } else if !viewModel.result.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\u{2728} AI RESULT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.result, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(viewModel.result)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
            }
        }
    }
}
