import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - File Item Model

struct DroppedFile: Identifiable {
    let id = UUID()
    var url: URL
    var name: String
    var fileType: String
    var size: String
    var extractedText: String = ""

    var typeIcon: String {
        switch fileType.lowercased() {
        case "pdf": return "\u{1F4D5}"
        case "txt", "rtf", "md": return "\u{1F4C4}"
        case "docx", "doc": return "\u{1F4DD}"
        case "xlsx", "xls", "csv": return "\u{1F4CA}"
        case "png", "jpg", "jpeg": return "\u{1F5BC}\u{FE0F}"
        default: return "\u{1F4CE}"
        }
    }

    var typeBadgeColor: String {
        switch fileType.lowercased() {
        case "pdf": return "#E91E8C"
        case "txt", "rtf", "md": return "#78909C"
        case "docx", "doc": return "#1976D2"
        case "xlsx", "xls", "csv": return "#2E7D32"
        default: return "#9E9E9E"
        }
    }
}

// MARK: - File Command Centre ViewModel

@Observable
class FileCommandCentreViewModel {
    var files: [DroppedFile] = []
    var selectedFile: DroppedFile?
    var result = ""
    var isProcessing = false
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func addFile(url: URL) {
        let name = url.lastPathComponent
        let ext = url.pathExtension
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs?[.size] as? Int64) ?? 0
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)

        var text = ""
        if ext.lowercased() == "pdf" {
            if let doc = PDFDocument(url: url) {
                for i in 0..<min(doc.pageCount, 10) {
                    text += doc.page(at: i)?.string ?? ""
                }
            }
        } else if ["txt", "md", "rtf", "csv"].contains(ext.lowercased()) {
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }

        let file = DroppedFile(url: url, name: name, fileType: ext, size: size, extractedText: String(text.prefix(3000)))
        files.insert(file, at: 0)
        selectedFile = file
    }

    func runAction(_ action: String) async {
        guard let file = selectedFile, !file.extractedText.isEmpty else {
            result = "Could not read file content."
            return
        }
        isProcessing = true
        let prompt: String
        switch action {
        case "Summarise":
            prompt = "Summarise this document in 5 bullet points:\n\n\(file.extractedText)"
        case "Flashcards":
            prompt = "Create 5 study flashcards (Q: / A:) from:\n\n\(file.extractedText)"
        case "Find Deadlines":
            prompt = "Find all dates and deadlines:\n\n\(file.extractedText)"
        case "Extract Data":
            prompt = "Extract key data, statistics, and figures from:\n\n\(file.extractedText)"
        case "Analyse":
            prompt = "Provide a brief analysis of this document's content, key points, and arguments:\n\n\(file.extractedText)"
        default:
            prompt = "Help with this text:\n\n\(file.extractedText)"
        }

        do {
            result = try await claudeService.ask(prompt)
        } catch {
            result = "Could not process — please try again."
        }
        isProcessing = false
    }
}

// MARK: - File Command Centre View

struct FileCommandCentreView: View {
    let claudeService: ClaudeService
    @State private var viewModel: FileCommandCentreViewModel
    @State private var isTargeted = false

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: FileCommandCentreViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("File Centre")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Drop Zone
                if viewModel.selectedFile == nil {
                    VStack(spacing: 12) {
                        Text("\u{1F4C1}")
                            .font(.system(size: 36))
                        Text("Drop Any File")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("PDF, TXT, CSV, DOCX — AI reads & analyses")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                        Button("Browse Files") {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                viewModel.addFile(url: url)
                            }
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(isTargeted ? Theme.Colors.rosePrimary : Theme.Colors.roseLight)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 14)
                    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                DispatchQueue.main.async { viewModel.addFile(url: url) }
                            }
                        }
                        return true
                    }

                    // Recent files
                    if !viewModel.files.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RECENT FILES")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            ForEach(viewModel.files.prefix(5)) { file in
                                Button(action: { viewModel.selectedFile = file }) {
                                    HStack(spacing: 8) {
                                        Text(file.typeIcon).font(.system(size: 14))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(file.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Theme.Colors.textPrimary)
                                                .lineLimit(1)
                                            Text(file.size)
                                                .font(.system(size: 9))
                                                .foregroundColor(Theme.Colors.textSoft)
                                        }
                                        Spacer()
                                        Text(file.fileType.uppercased())
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(Color(hex: file.typeBadgeColor))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: file.typeBadgeColor).opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    }
                } else {
                    // Selected file actions
                    fileActionView
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }

    var fileActionView: some View {
        VStack(spacing: 10) {
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
                    Text("\(file.typeIcon) \(file.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)

            // Action buttons
            let actions = ["Summarise", "Flashcards", "Find Deadlines", "Extract Data", "Analyse"]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(actions, id: \.self) { action in
                    Button(action: { Task { await viewModel.runAction(action) } }) {
                        Text(action)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.Colors.textMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.6))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.glassBorder, lineWidth: 1))
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
                    Text("Reading file...")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
            } else if !viewModel.result.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\u{2728} RESULT")
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
