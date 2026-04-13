import SwiftUI

// MARK: - Grocery Models

struct GroceryList: Codable {
    var sections: [GrocerySection] = GrocerySection.defaults
}

struct GrocerySection: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var items: [GroceryItem]

    init(id: UUID = UUID(), name: String, icon: String, items: [GroceryItem] = []) {
        self.id = id; self.name = name; self.icon = icon; self.items = items
    }

    static var defaults: [GrocerySection] {
        [
            GrocerySection(name: "Produce", icon: "\u{1F966}"),
            GrocerySection(name: "Protein", icon: "\u{1F357}"),
            GrocerySection(name: "Dairy", icon: "\u{1F95B}"),
            GrocerySection(name: "Pantry", icon: "\u{1F35E}"),
            GrocerySection(name: "Snacks", icon: "\u{1F36A}"),
        ]
    }
}

struct GroceryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: String
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, quantity: String = "", isChecked: Bool = false) {
        self.id = id; self.name = name; self.quantity = quantity; self.isChecked = isChecked
    }
}

// MARK: - Grocery ViewModel

@Observable
class GroceryViewModel {
    var list = GroceryList()

    init() {
        Task { await load() }
    }

    func load() async {
        list = await DataStore.shared.loadOrDefault(GroceryList.self, from: "grocery.json", default: GroceryList())
    }

    func save() {
        Task { try? await DataStore.shared.save(list, to: "grocery.json") }
    }

    func addItem(to sectionIndex: Int, name: String, quantity: String) {
        guard !name.isEmpty else { return }
        list.sections[sectionIndex].items.append(GroceryItem(name: name, quantity: quantity))
        save()
    }

    func toggleItem(section: Int, item: Int) {
        list.sections[section].items[item].isChecked.toggle()
        save()
    }

    func removeChecked() {
        for i in list.sections.indices {
            list.sections[i].items.removeAll { $0.isChecked }
        }
        save()
    }

    var totalItems: Int { list.sections.flatMap(\.items).count }
    var checkedItems: Int { list.sections.flatMap(\.items).filter(\.isChecked).count }
}

// MARK: - Grocery List View

struct GroceryListView: View {
    @State private var viewModel = GroceryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Grocery List")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    if viewModel.checkedItems > 0 {
                        Button(action: viewModel.removeChecked) {
                            Text("Clear checked")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.roseDeep)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(viewModel.checkedItems)/\(viewModel.totalItems)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Gradients.rosePrimary)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 14)

                // Sections
                ForEach(Array(viewModel.list.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    GrocerySectionView(
                        section: section,
                        sectionIndex: sectionIndex,
                        viewModel: viewModel
                    )
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Grocery Section

struct GrocerySectionView: View {
    let section: GrocerySection
    let sectionIndex: Int
    let viewModel: GroceryViewModel
    @State private var newItem = ""
    @State private var newQty = ""
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(section.icon)
                        .font(.system(size: 14))
                    Text(section.name.uppercased())
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("\(section.items.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Theme.Colors.rosePale)
                        .cornerRadius(6)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Items
                ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, item in
                    HStack(spacing: 8) {
                        Button(action: { viewModel.toggleItem(section: sectionIndex, item: itemIndex) }) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(item.isChecked ? .green : Theme.Colors.roseLight)
                        }
                        .buttonStyle(.plain)

                        Text(item.name)
                            .font(.system(size: 12))
                            .foregroundColor(item.isChecked ? Theme.Colors.textXSoft : Theme.Colors.textPrimary)
                            .strikethrough(item.isChecked)
                        Spacer()
                        if !item.quantity.isEmpty {
                            Text(item.quantity)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.rosePale.opacity(0.5))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Add item
                HStack(spacing: 6) {
                    TextField("Add item...", text: $newItem)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(6)
                    TextField("Qty", text: $newQty)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(6)
                        .frame(width: 50)
                    Button(action: {
                        viewModel.addItem(to: sectionIndex, name: newItem, quantity: newQty)
                        newItem = ""; newQty = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItem.isEmpty)
                }
                .onSubmit {
                    viewModel.addItem(to: sectionIndex, name: newItem, quantity: newQty)
                    newItem = ""; newQty = ""
                }
            }
        }
        .glassCard(padding: 10)
    }
}
