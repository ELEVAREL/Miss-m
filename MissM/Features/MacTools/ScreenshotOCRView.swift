import SwiftUI
import Vision

// MARK: - Screenshot OCR ViewModel

@Observable
class ScreenshotOCRViewModel {
    var capturedImage: NSImage?
    var ocrText = ""
    var aiResult = ""
    var isProcessing = false
    var isExplaining = false
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func captureScreen() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        let tmpPath = NSTemporaryDirectory() + "missm_screenshot.png"
        task.arguments = ["-i", tmpPath]
        task.launch()
        task.waitUntilExit()
        if let image = NSImage(contentsOfFile: tmpPath) {
            capturedImage = image
            Task { await runOCR(image: image) }
        }
    }

    func runOCR(image: NSImage) async {
        isProcessing = true
        guard let tiff = image.tiffRepresentation,
              let cgImage = NSBitmapImageRep(data: tiff)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            isProcessing = false
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])

        let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
        ocrText = text
        isProcessing = false
    }

    func explain() async {
        guard !ocrText.isEmpty else { return }
        isExplaining = true
        do {
            aiResult = try await claudeService.ask("Explain this text in simple terms for a university student. Be concise:\n\n\(ocrText.prefix(2000))")
        } catch {
            aiResult = "Could not explain — please try again."
        }
        isExplaining = false
    }

    func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ocrText, forType: .string)
    }

    func clear() {
        capturedImage = nil
        ocrText = ""
        aiResult = ""
    }
}

// MARK: - Screenshot OCR View

struct ScreenshotOCRView: View {
    let claudeService: ClaudeService
    @State private var viewModel: ScreenshotOCRViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: ScreenshotOCRViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Screenshot OCR")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    if viewModel.capturedImage != nil {
                        Button(action: viewModel.clear) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.roseDeep)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)

                if viewModel.capturedImage == nil {
                    // Capture prompt
                    VStack(spacing: 14) {
                        Text("\u{1F4F7}")
                            .font(.system(size: 36))
                        Text("Capture Screen Region")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Select an area to extract text using Vision OCR")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                        Button("Capture") {
                            viewModel.captureScreen()
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCard(padding: 14)
                    .padding(.horizontal, 14)
                } else {
                    // Preview
                    if let image = viewModel.capturedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .padding(.horizontal, 14)
                    }

                    // OCR Result
                    if viewModel.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.6)
                            Text("Extracting text...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    } else if !viewModel.ocrText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\u{1F4DD} EXTRACTED TEXT")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button(action: viewModel.copyText) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                }
                                .buttonStyle(.plain)
                            }
                            Text(viewModel.ocrText)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineSpacing(2)
                                .textSelection(.enabled)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)

                        // Actions
                        HStack(spacing: 6) {
                            Button(action: { Task { await viewModel.explain() } }) {
                                HStack(spacing: 4) {
                                    if viewModel.isExplaining { ProgressView().scaleEffect(0.4) }
                                    Text(viewModel.isExplaining ? "..." : "\u{1F4A1} Explain")
                                }
                                .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(RoseButtonStyle())

                            Button(action: viewModel.copyText) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.textMedium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button("New Capture") { viewModel.captureScreen() }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.textMedium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)

                        // AI Explanation
                        if !viewModel.aiResult.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\u{2728} AI EXPLANATION")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Text(viewModel.aiResult)
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

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}
