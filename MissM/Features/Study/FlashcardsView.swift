import SwiftUI

// MARK: - Flashcard Models

struct FlashcardDeck: Identifiable, Codable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, cards: [Flashcard] = [], createdAt: Date = Date()) {
        self.id = id; self.name = name; self.cards = cards; self.createdAt = createdAt
    }
}

struct Flashcard: Identifiable, Codable {
    let id: UUID
    var question: String
    var answer: String
    var result: Result?

    init(id: UUID = UUID(), question: String, answer: String, result: Result? = nil) {
        self.id = id; self.question = question; self.answer = answer; self.result = result
    }

    enum Result: String, Codable { case correct, wrong, almost }
}

// MARK: - Flashcards ViewModel

@Observable
class FlashcardsViewModel {
    var decks: [FlashcardDeck] = []
    var currentDeckIndex: Int? = nil
    var currentCardIndex = 0
    var isFlipped = false
    var generateNotes = ""
    var isGenerating = false
    var dragOffset: CGFloat = 0
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await loadDecks() }
    }

    var currentDeck: FlashcardDeck? {
        guard let i = currentDeckIndex, i < decks.count else { return nil }
        return decks[i]
    }

    var currentCard: Flashcard? {
        guard let deck = currentDeck, currentCardIndex < deck.cards.count else { return nil }
        return deck.cards[currentCardIndex]
    }

    var stats: (correct: Int, wrong: Int, remaining: Int) {
        guard let deck = currentDeck else { return (0, 0, 0) }
        let correct = deck.cards.filter { $0.result == .correct }.count
        let wrong = deck.cards.filter { $0.result == .wrong }.count
        let remaining = deck.cards.filter { $0.result == nil }.count
        return (correct, wrong, remaining)
    }

    var accuracy: Int {
        let s = stats
        let total = s.correct + s.wrong
        return total > 0 ? Int(Double(s.correct) / Double(total) * 100) : 0
    }

    func flip() { isFlipped.toggle() }

    func nextCard() {
        guard let deck = currentDeck, currentCardIndex < deck.cards.count - 1 else { return }
        isFlipped = false
        currentCardIndex += 1
    }

    func previousCard() {
        guard currentCardIndex > 0 else { return }
        isFlipped = false
        currentCardIndex -= 1
    }

    func answer(_ result: Flashcard.Result) {
        guard let di = currentDeckIndex else { return }
        decks[di].cards[currentCardIndex].result = result
        isFlipped = false
        if currentCardIndex < (currentDeck?.cards.count ?? 1) - 1 {
            currentCardIndex += 1
        }
        save()
    }

    func selectDeck(_ index: Int) {
        currentDeckIndex = index
        currentCardIndex = 0
        isFlipped = false
    }

    func resetDeck() {
        guard let di = currentDeckIndex else { return }
        for i in decks[di].cards.indices {
            decks[di].cards[i].result = nil
        }
        currentCardIndex = 0
        isFlipped = false
        save()
    }

    func generateFromNotes() async {
        guard !generateNotes.isEmpty else { return }
        isGenerating = true
        let prompt = """
        Generate 8 flashcard question-answer pairs from these study notes. Return ONLY a JSON array like:
        [{"question":"...","answer":"..."},...]
        Notes: \(generateNotes)
        """
        do {
            let response = try await claudeService.ask(prompt)
            if let data = response.data(using: .utf8),
               let cards = try? JSONDecoder().decode([FlashcardJSON].self, from: data) {
                let newCards = cards.map { Flashcard(question: $0.question, answer: $0.answer) }
                let deck = FlashcardDeck(name: "Generated Deck", cards: newCards)
                decks.append(deck)
                currentDeckIndex = decks.count - 1
                currentCardIndex = 0
                generateNotes = ""
                save()
            }
        } catch {}
        isGenerating = false
    }

    func loadDecks() async {
        decks = await DataStore.shared.loadOrDefault([FlashcardDeck].self, from: "flashcards.json", default: [])
    }

    func save() {
        Task { try? await DataStore.shared.save(decks, to: "flashcards.json") }
    }

    struct FlashcardJSON: Codable { let question: String; let answer: String }
}

// MARK: - Flashcards View

struct FlashcardsView: View {
    let claudeService: ClaudeService
    @State private var viewModel: FlashcardsViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: FlashcardsViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(alignment: .lastTextBaseline) {
                    Text("Flashcards")
                        .font(Theme.Fonts.display(22))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    if viewModel.currentDeck != nil {
                        Button(action: { viewModel.resetDeck() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Reset")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Theme.Colors.roseDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.rosePale.opacity(0.6))
                            .cornerRadius(Theme.Radius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                if let card = viewModel.currentCard, let deck = viewModel.currentDeck {
                    // Card counter
                    Text("\(viewModel.currentCardIndex + 1) of \(deck.cards.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                        .tracking(1)

                    // 3D Flip Card with swipe
                    ZStack {
                        FlipCardView3D(card: card, isFlipped: viewModel.isFlipped)
                            .onTapGesture { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { viewModel.flip() } }
                    }
                    .offset(x: viewModel.dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                viewModel.dragOffset = value.translation.width * 0.6
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 60
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if value.translation.width < -threshold {
                                        viewModel.nextCard()
                                    } else if value.translation.width > threshold {
                                        viewModel.previousCard()
                                    }
                                    viewModel.dragOffset = 0
                                }
                            }
                    )
                    .padding(.horizontal, 16)

                    // Navigation arrows
                    HStack(spacing: 24) {
                        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.previousCard() } }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    viewModel.currentCardIndex > 0
                                    ? Theme.Colors.rosePrimary
                                    : Theme.Colors.roseLight.opacity(0.5)
                                )
                                .shadow(color: Theme.Colors.shadow, radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.currentCardIndex == 0)

                        // Tap to flip hint
                        Text(viewModel.isFlipped ? "Tap to see question" : "Tap to reveal answer")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textXSoft)
                            .frame(maxWidth: .infinity)

                        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.nextCard() } }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    viewModel.currentCardIndex < deck.cards.count - 1
                                    ? Theme.Colors.rosePrimary
                                    : Theme.Colors.roseLight.opacity(0.5)
                                )
                                .shadow(color: Theme.Colors.shadow, radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.currentCardIndex >= deck.cards.count - 1)
                    }
                    .padding(.horizontal, 20)

                    // Progress dots
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(Array(deck.cards.enumerated()), id: \.element.id) { index, c in
                                Circle()
                                    .fill(dotColor(for: c, isCurrent: index == viewModel.currentCardIndex))
                                    .frame(
                                        width: index == viewModel.currentCardIndex ? 10 : 7,
                                        height: index == viewModel.currentCardIndex ? 10 : 7
                                    )
                                    .shadow(
                                        color: index == viewModel.currentCardIndex ? Theme.Colors.rosePrimary.opacity(0.5) : .clear,
                                        radius: 3
                                    )
                                    .animation(.spring(response: 0.3), value: viewModel.currentCardIndex)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            viewModel.currentCardIndex = index
                                            viewModel.isFlipped = false
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Stats row
                    HStack(spacing: 8) {
                        FlashcardStatBadge(value: "\(viewModel.stats.correct)", label: "Got It", color: .green, icon: "checkmark.circle.fill")
                        FlashcardStatBadge(value: "\(viewModel.stats.wrong)", label: "Wrong", color: Color(hex: "#E53935"), icon: "xmark.circle.fill")
                        FlashcardStatBadge(value: "\(viewModel.stats.remaining)", label: "Left", color: Theme.Colors.textSoft, icon: "circle.dashed")
                        FlashcardStatBadge(value: "\(viewModel.accuracy)%", label: "Score", color: Theme.Colors.rosePrimary, icon: "star.fill")
                    }
                    .padding(.horizontal, 16)

                    // Answer Buttons (show when flipped)
                    if viewModel.isFlipped {
                        HStack(spacing: 10) {
                            AnswerPill(label: "Wrong", icon: "xmark", color: Color(hex: "#E53935")) { viewModel.answer(.wrong) }
                            AnswerPill(label: "Almost", icon: "minus", color: .orange) { viewModel.answer(.almost) }
                            AnswerPill(label: "Got It!", icon: "checkmark", color: .green) { viewModel.answer(.correct) }
                        }
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    // No deck selected
                    if viewModel.decks.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.Gradients.rosePrimary)
                                .padding(.top, 24)
                            Text("No flashcard decks yet")
                                .font(Theme.Fonts.display(16))
                                .foregroundColor(Theme.Colors.textMedium)
                            Text("Paste your study notes below and AI will create beautiful flashcards for you")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .padding(.top, 10)
                    }
                }

                // Deck List
                if !viewModel.decks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DECKS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)

                        ForEach(Array(viewModel.decks.enumerated()), id: \.element.id) { index, deck in
                            Button(action: { withAnimation(.spring(response: 0.35)) { viewModel.selectDeck(index) } }) {
                                HStack(spacing: 10) {
                                    // Deck icon
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                index == viewModel.currentDeckIndex
                                                ? AnyShapeStyle(Theme.Gradients.rosePrimary)
                                                : AnyShapeStyle(Theme.Colors.rosePale)
                                            )
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "rectangle.stack.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(index == viewModel.currentDeckIndex ? .white : Theme.Colors.rosePrimary)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(deck.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text("\(deck.cards.count) cards")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.Colors.textSoft)
                                    }
                                    Spacer()
                                    if index == viewModel.currentDeckIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.Colors.rosePrimary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.Colors.textXSoft)
                                    }
                                }
                                .padding(10)
                                .background(
                                    index == viewModel.currentDeckIndex
                                    ? Theme.Colors.rosePale.opacity(0.5)
                                    : Color.white.opacity(0.5)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassCard(padding: 12)
                    .padding(.horizontal, 16)
                }

                // Generate from Notes
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Gradients.rosePrimary)
                        Text("GENERATE FROM NOTES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                    }

                    ZStack(alignment: .topLeading) {
                        if viewModel.generateNotes.isEmpty {
                            Text("Paste your lecture notes, textbook excerpt, or study material here...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textXSoft)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $viewModel.generateNotes)
                            .font(.system(size: 11))
                            .frame(height: 90)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                    }
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.roseLight, lineWidth: 1.5)
                    )

                    Button(action: { Task { await viewModel.generateFromNotes() } }) {
                        HStack(spacing: 6) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                            }
                            Text(viewModel.isGenerating ? "Generating..." : "Generate Flashcards")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RoseButtonStyle())
                    .disabled(viewModel.generateNotes.isEmpty || viewModel.isGenerating)
                    .opacity(viewModel.generateNotes.isEmpty ? 0.5 : 1)
                }
                .glassCard(padding: 12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.top, 10)
        }
    }

    func dotColor(for card: Flashcard, isCurrent: Bool) -> Color {
        if isCurrent { return Theme.Colors.rosePrimary }
        switch card.result {
        case .correct: return .green
        case .wrong: return Color(hex: "#E53935")
        case .almost: return .orange
        case nil: return Theme.Colors.roseLight.opacity(0.5)
        }
    }
}

// MARK: - 3D Flip Card View (Clean Design)

struct FlipCardView3D: View {
    let card: Flashcard
    let isFlipped: Bool
    @State private var shadowRadius: CGFloat = 10

    var body: some View {
        ZStack {
            // Front face — Question (clean, minimal)
            VStack(spacing: 0) {
                Spacer()

                Text(card.question)
                    .font(.custom("PlayfairDisplay-Italic", size: 18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)

                Spacer()

                Text("tap to reveal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                    .padding(.bottom, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                ZStack {
                    Theme.Gradients.heroCard
                    // Subtle top-left light
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                }
            )
            .cornerRadius(Theme.Radius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.roseDeep.opacity(0.3), radius: isFlipped ? 4 : shadowRadius, x: 0, y: isFlipped ? 2 : 8)
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)

            // Back face — Answer (clean white with rose accent)
            VStack(spacing: 0) {
                // Rose accent line
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Gradients.rosePrimary)
                    .frame(width: 40, height: 3)
                    .padding(.top, 16)

                Spacer()

                Text(card.answer)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.white)
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.Radius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .stroke(Theme.Colors.roseLight.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.shadow, radius: isFlipped ? shadowRadius : 4, x: 0, y: isFlipped ? 8 : 2)
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: isFlipped)
        .onChange(of: isFlipped) { _, flipped in
            withAnimation(.easeOut(duration: 0.4)) {
                shadowRadius = flipped ? 14 : 10
            }
        }
    }
}

// MARK: - Flashcard Stat Badge

struct FlashcardStatBadge: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Theme.Colors.textXSoft)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Answer Pill

struct AnswerPill: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isHovered ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(isHovered ? color : Color.clear)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color, lineWidth: 1.5)
            )
            .shadow(color: isHovered ? color.opacity(0.25) : Color.clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.Animations.quickFade, value: isHovered)
    }
}

// MARK: - Legacy compat aliases
typealias FlashcardStat = FlashcardStatBadge
typealias AnswerButton = AnswerPill
typealias FlipCardView = FlipCardView3D
