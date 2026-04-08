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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FLASHCARDS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("Study Cards")
                        .font(.custom("PlayfairDisplay-Italic", size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
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
            .padding(.vertical, 10)

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

// MARK: - Deck Card
struct DeckCard: View {
    let deck: FlashcardDeck
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(deck.cards.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("cards")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 50, height: 50)
                .background(Theme.Gradients.rosePrimary)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(deck.course)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                    // Progress
                    HStack(spacing: 4) {
                        ProgressView(value: Double(deck.masteredCount), total: max(Double(deck.cards.count), 1))
                            .tint(Theme.Colors.rosePrimary)
                            .frame(width: 80)
                        Text("\(deck.masteredCount)/\(deck.cards.count)")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
            .padding(10)
            .glassCard(padding: 0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flashcard Study View
struct FlashcardStudyView: View {
    let viewModel: FlashcardsViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Back button + deck info
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
                Spacer()
                Text("\(viewModel.currentCardIndex + 1)/\(viewModel.currentDeck?.cards.count ?? 0)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
            }
            .padding(.horizontal, 16)

            // Progress dots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<(viewModel.currentDeck?.cards.count ?? 0), id: \.self) { index in
                        Circle()
                            .fill(dotColor(for: index))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Flip card
            if let card = viewModel.currentCard {
                FlipCard(
                    front: card.front,
                    back: card.back,
                    isFlipped: viewModel.isFlipped
                )
                .onTapGesture { viewModel.flipCard() }
                .padding(.horizontal, 16)
            }

            // Controls
            HStack(spacing: 20) {
                Button(action: { viewModel.previousCard() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.roseLight)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentCardIndex == 0)

                Button(action: { viewModel.markMastered() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.currentCard?.isMastered == true ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(viewModel.currentCard?.isMastered == true ? "Mastered" : "Mark Known")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(viewModel.currentCard?.isMastered == true ? .green : Theme.Colors.textMedium)
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.nextCard() }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentCardIndex >= (viewModel.currentDeck?.cards.count ?? 1) - 1)
            }
            .padding(.vertical, 8)

            // Add card
            AddCardInline(viewModel: viewModel)
                .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func dotColor(for index: Int) -> Color {
        let cards = viewModel.currentDeck?.cards ?? []
        if index == viewModel.currentCardIndex {
            return Theme.Colors.rosePrimary
        }
        if index < cards.count && cards[index].isMastered {
            return .green
        }
        return Theme.Colors.rosePale
    }
}

// MARK: - 3D Flip Card
struct FlipCard: View {
    let front: String
    let back: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            // Front
            VStack(spacing: 12) {
                Text("Q")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.rosePrimary.opacity(0.5))
                Text(front)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Spacer()
                Text("Tap to flip")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 180)
            .glassCard(padding: 0)
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back
            VStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Text(back)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Spacer()
                Text("Tap to flip back")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(Theme.Gradients.heroCard)
            .cornerRadius(Theme.Radius.md)
            .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)
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
