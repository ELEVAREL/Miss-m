import SwiftUI

// MARK: - Flashcards View (Phase 2)
// 3D flip cards + deck management + AI generation

struct FlashcardsView: View {
    let claudeService: ClaudeService
    @State private var viewModel: FlashcardsViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: FlashcardsViewModel(claudeService: claudeService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (per design: Playfair "Flashcard Quiz")
            HStack(alignment: .firstTextBaseline) {
                Text("Flashcard ")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.textPrimary)
                + Text("Quiz")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Button(action: { viewModel.showNewDeck = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Deck")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(RoseButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Text("AI-generated from notes · spaced repetition")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if viewModel.currentDeck == nil {
                // Deck list
                DeckListView(viewModel: viewModel)
            } else {
                // Flashcard study mode
                FlashcardStudyView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showNewDeck) {
            NewDeckSheet(viewModel: viewModel)
        }
        .task { await viewModel.loadData() }
    }
}

// MARK: - Deck List
struct DeckListView: View {
    let viewModel: FlashcardsViewModel

    var body: some View {
        ScrollView {
            if viewModel.decks.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)
                    Text("🃏").font(.system(size: 40))
                    Text("No Decks Yet")
                        .font(.custom("PlayfairDisplay-Italic", size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Text("Create a deck or let AI generate\nflashcards from your notes.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                        .multilineTextAlignment(.center)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.decks) { deck in
                        DeckCard(deck: deck, onTap: { viewModel.selectDeck(deck) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

// MARK: - Deck Card (per design: colored dot, info, badge)
struct DeckCard: View {
    let deck: FlashcardDeck
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Colored dot
                Circle()
                    .fill(deckDotColor)
                    .frame(width: 10, height: 10)

                // Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(deck.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("\(deck.cards.count) cards · \(deck.masteredCount) mastered")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }

                Spacer()

                // Badge
                Text(deckBadgeLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(deckBadgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(deckBadgeColor.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(isHovered ? Color.white : Color.white.opacity(0.65))
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .offset(x: isHovered ? 2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var deckDotColor: Color {
        if deck.masteredCount == deck.cards.count && !deck.cards.isEmpty { return .green }
        if deck.masteredCount > 0 { return .orange }
        return .red
    }

    private var deckBadgeLabel: String {
        if deck.cards.isEmpty { return "New" }
        if deck.masteredCount == deck.cards.count { return "✓ OK" }
        if deck.masteredCount > 0 { return "Review" }
        return "Due"
    }

    private var deckBadgeColor: Color {
        if deck.cards.isEmpty { return Color.purple }
        if deck.masteredCount == deck.cards.count { return .green }
        if deck.masteredCount > 0 { return .orange }
        return .red
    }
}

// MARK: - Flashcard Study View (per design: progress dots, stats, 3-button controls)
struct FlashcardStudyView: View {
    let viewModel: FlashcardsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Back button + deck badge + card count
                HStack {
                    Button(action: { viewModel.deselectDeck() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Decks")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)

                    // Active deck badge
                    if let deck = viewModel.currentDeck {
                        Text("\(deck.title) ×")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.rosePrimary.opacity(0.1))
                            .cornerRadius(18)
                    }

                    Spacer()
                    Text("Card \(viewModel.currentCardIndex + 1) of \(viewModel.currentDeck?.cards.count ?? 0)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                .padding(.horizontal, 16)

                // Progress dots (per design: colored segments)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(0..<(viewModel.currentDeck?.cards.count ?? 0), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(dotColor(for: index))
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Flip card
                if let card = viewModel.currentCard {
                    FlipCard(
                        front: card.front,
                        back: card.back,
                        course: viewModel.currentDeck?.course ?? "",
                        isFlipped: viewModel.isFlipped
                    )
                    .onTapGesture { viewModel.flipCard() }
                    .padding(.horizontal, 16)
                }

                // Stats row (per design: 4 stats)
                FlashcardStatsRow(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // 3-button controls (per design: Wrong, Almost, Got It)
                HStack(spacing: 10) {
                    AnswerButton(label: "✕ Wrong", color: .red) {
                        viewModel.nextCard()
                    }
                    AnswerButton(label: "~ Almost", color: .orange) {
                        viewModel.nextCard()
                    }
                    AnswerButton(label: "✓ Got It", color: .green) {
                        viewModel.markMastered()
                        viewModel.nextCard()
                    }
                }
                .padding(.horizontal, 16)

                // Additional buttons
                HStack(spacing: 8) {
                    Button("⏭ Skip") { viewModel.nextCard() }
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textMedium)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.75))
                        .cornerRadius(11)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))

                    Button("🔀 Shuffle") {}
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textMedium)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.75))
                        .cornerRadius(11)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))

                    Button("End Session") { viewModel.deselectDeck() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(RoseButtonStyle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // Add card
                AddCardInline(viewModel: viewModel)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
    }

    private func dotColor(for index: Int) -> Color {
        let cards = viewModel.currentDeck?.cards ?? []
        if index == viewModel.currentCardIndex {
            return Theme.Colors.roseMid
        }
        if index < cards.count && cards[index].isMastered {
            return .green
        }
        return Theme.Colors.rosePrimary.opacity(0.12)
    }
}

// MARK: - Answer Button (per design: colored border + bg)
struct AnswerButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color == .red ? Color(hex: "#B71C1C") : color == .orange ? Color(hex: "#C65200") : Color(hex: "#2E7D32"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color.opacity(0.08))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Row (per design: 4 stat cards)
struct FlashcardStatsRow: View {
    let viewModel: FlashcardsViewModel

    var body: some View {
        HStack(spacing: 10) {
            StatCell(value: "\(viewModel.masteredInSession)", label: "Got It ✓", color: .green)
            StatCell(value: "\(viewModel.wrongInSession)", label: "Wrong ✕", color: .red)
            StatCell(value: "\(viewModel.remainingCount)", label: "Remaining", color: Theme.Colors.textSoft)
            StatCell(value: "\(viewModel.accuracy)%", label: "Accuracy", color: Theme.Colors.textPrimary)
        }
    }
}

struct StatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom("CormorantGaramond-SemiBold", size: 22))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.Colors.textSoft)
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.65))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
}

// MARK: - 3D Flip Card (per design: gradient front, white back)
struct FlipCard: View {
    let front: String
    let back: String
    var course: String = ""
    let isFlipped: Bool

    var body: some View {
        ZStack {
            // Front — gradient (per design: r7 → r6 → r5)
            VStack(alignment: .leading, spacing: 0) {
                Text(course.isEmpty ? "FLASHCARD" : course.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.bottom, 10)

                Spacer()

                Text(front)
                    .font(.custom("PlayfairDisplay-Italic", size: 17))
                    .foregroundColor(.white)
                    .lineSpacing(4)

                Spacer()

                Text("Tap to reveal answer →")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.5)
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.roseDark, Theme.Colors.roseDeep, Theme.Colors.rosePrimary.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(22)
            .shadow(color: Color(hex: "#C2185B").opacity(0.25), radius: 20, x: 0, y: 8)
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back — white card
            VStack(alignment: .leading, spacing: 0) {
                Text("ANSWER")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                    .padding(.bottom, 8)

                Spacer()

                Text(back)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textMedium)
                    .lineSpacing(5)

                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(Color.white)
            .cornerRadius(22)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: Color(hex: "#C2185B").opacity(0.12), radius: 20, x: 0, y: 8)
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFlipped)
    }
}

// MARK: - Add Card Inline
struct AddCardInline: View {
    let viewModel: FlashcardsViewModel
    @State private var front = ""
    @State private var back = ""
    @State private var showGenerate = false
    @State private var notesForGeneration = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ADD CARD")
                    .font(.custom("CormorantGaramond-SemiBold", size: 9))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("AI Generate") { showGenerate.toggle() }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }

            if showGenerate {
                VStack(spacing: 6) {
                    TextEditor(text: $notesForGeneration)
                        .font(.system(size: 10))
                        .scrollContentBackground(.hidden)
                        .frame(height: 60)
                        .padding(6)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.roseLight, lineWidth: 1))

                    Button("Generate Cards from Notes") {
                        Task { await viewModel.generateCards(from: notesForGeneration) }
                        showGenerate = false
                        notesForGeneration = ""
                    }
                    .buttonStyle(RoseButtonStyle())
                    .font(.system(size: 10))
                    .disabled(notesForGeneration.isEmpty)

                    if viewModel.isGenerating {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.5)
                            Text("Generating...").font(.system(size: 9)).foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    TextField("Front (question)", text: $front)
                    TextField("Back (answer)", text: $back)
                    Button(action: {
                        guard !front.isEmpty, !back.isEmpty else { return }
                        viewModel.addCard(front: front, back: back)
                        front = ""
                        back = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .padding(8)
                .background(Color.white.opacity(0.7))
                .cornerRadius(8)
            }
        }
        .padding(10)
        .glassCard(padding: 0)
    }
}

// MARK: - New Deck Sheet
struct NewDeckSheet: View {
    let viewModel: FlashcardsViewModel
    @State private var title = ""
    @State private var course = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("New Deck")
                .font(.custom("PlayfairDisplay-Italic", size: 18))
                .foregroundColor(Theme.Colors.rosePrimary)

            TextField("Deck title", text: $title)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            TextField("Course", text: $course)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSoft)
                Button("Create") {
                    viewModel.createDeck(title: title, course: course)
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Theme.Colors.roseUltra)
    }
}

// MARK: - Flashcards ViewModel
@Observable
class FlashcardsViewModel {
    var decks: [FlashcardDeck] = []
    var currentDeckIndex: Int?
    var currentCardIndex = 0
    var isFlipped = false
    var showNewDeck = false
    var isGenerating = false

    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    var currentDeck: FlashcardDeck? {
        guard let index = currentDeckIndex, index < decks.count else { return nil }
        return decks[index]
    }

    var currentCard: Flashcard? {
        guard let deck = currentDeck, currentCardIndex < deck.cards.count else { return nil }
        return deck.cards[currentCardIndex]
    }

    var masteredInSession: Int {
        currentDeck?.cards.filter { $0.isMastered }.count ?? 0
    }

    var wrongInSession: Int {
        let total = currentDeck?.cards.count ?? 0
        return max(0, total - masteredInSession - remainingCount)
    }

    var remainingCount: Int {
        let total = currentDeck?.cards.count ?? 0
        return max(0, total - currentCardIndex - 1)
    }

    var accuracy: Int {
        let total = masteredInSession + wrongInSession
        if total == 0 { return 0 }
        return Int(Double(masteredInSession) / Double(total) * 100)
    }

    func loadData() async {
        let loaded = try? await DataStore.shared.loadDecks()
        if let loaded { decks = loaded }
    }

    func saveData() {
        Task { try? await DataStore.shared.saveDecks(decks) }
    }

    func createDeck(title: String, course: String) {
        let deck = FlashcardDeck(title: title, course: course)
        decks.insert(deck, at: 0)
        currentDeckIndex = 0
        currentCardIndex = 0
        saveData()
    }

    func selectDeck(_ deck: FlashcardDeck) {
        currentDeckIndex = decks.firstIndex(where: { $0.id == deck.id })
        currentCardIndex = 0
        isFlipped = false
    }

    func deselectDeck() {
        currentDeckIndex = nil
        currentCardIndex = 0
        isFlipped = false
    }

    func flipCard() {
        isFlipped.toggle()
    }

    func nextCard() {
        guard let deck = currentDeck, currentCardIndex < deck.cards.count - 1 else { return }
        currentCardIndex += 1
        isFlipped = false
    }

    func previousCard() {
        guard currentCardIndex > 0 else { return }
        currentCardIndex -= 1
        isFlipped = false
    }

    func markMastered() {
        guard let deckIndex = currentDeckIndex else { return }
        decks[deckIndex].cards[currentCardIndex].isMastered.toggle()
        saveData()
    }

    func addCard(front: String, back: String) {
        guard let deckIndex = currentDeckIndex else { return }
        decks[deckIndex].cards.append(Flashcard(front: front, back: back))
        saveData()
    }

    func generateCards(from notes: String) async {
        guard let deckIndex = currentDeckIndex else { return }
        isGenerating = true
        defer { isGenerating = false }

        let prompt = """
        Generate flashcards from these notes. Return EXACTLY in this format, one card per line:
        Q: [question] | A: [answer]

        Generate 5-8 cards. Keep questions and answers concise.

        Notes:
        \(notes)
        """

        do {
            let response = try await claudeService.ask(prompt)
            let cards = response.split(separator: "\n")
                .filter { $0.contains("Q:") && $0.contains("A:") }
                .compactMap { line -> Flashcard? in
                    let parts = line.split(separator: "|", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    let q = parts[0].replacingOccurrences(of: "Q:", with: "").trimmingCharacters(in: .whitespaces)
                    let a = parts[1].replacingOccurrences(of: "A:", with: "").trimmingCharacters(in: .whitespaces)
                    guard !q.isEmpty, !a.isEmpty else { return nil }
                    return Flashcard(front: q, back: a)
                }
            decks[deckIndex].cards.append(contentsOf: cards)
            saveData()
        } catch {
            // Error handled silently
        }
    }
}
