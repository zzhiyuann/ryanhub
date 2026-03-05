import SwiftUI

struct GroceryListEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: GroceryListViewModel
    var onSave: (() -> Void)?

    @State private var itemName: String = ""
    @State private var category: GroceryCategory = .other
    @State private var quantity: Int = 1
    @State private var unit: GroceryUnit = .piece
    @State private var estimatedPrice: Double = 0.0
    @State private var priority: GroceryPriority = .needed
    @State private var notes: String = ""

    private var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Grocery List",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                var entry = GroceryListEntry()
                entry.itemName = itemName.trimmingCharacters(in: .whitespaces)
                entry.category = category
                entry.quantity = quantity
                entry.unit = unit
                entry.estimatedPrice = estimatedPrice
                entry.isPurchased = false
                entry.priority = priority
                entry.notes = notes
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {
            EntryFormSection(title: "Item") {
                TextField("Item name (e.g. Whole Milk)", text: $itemName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Category") {
                Picker("Category", selection: $category) {
                    ForEach(GroceryCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Quantity & Unit") {
                Stepper(
                    value: $quantity,
                    in: 1...999
                ) {
                    HStack {
                        Text("Quantity")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(quantity)")
                            .font(.hubBody)
                            .foregroundStyle(Color.hubPrimary)
                    }
                }

                Picker("Unit", selection: $unit) {
                    ForEach(GroceryUnit.allCases) { u in
                        Label(u.displayName, systemImage: u.icon).tag(u)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Estimated Price") {
                HStack {
                    Text("Per unit")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Spacer()
                    Text(estimatedPrice == 0 ? "Free / Unknown" : "$\(String(format: "%.2f", estimatedPrice))")
                        .font(.hubBody)
                        .foregroundStyle(estimatedPrice == 0
                            ? AdaptiveColors.textSecondary(for: colorScheme)
                            : AdaptiveColors.textPrimary(for: colorScheme))
                }
                Slider(value: $estimatedPrice, in: 0...100, step: 0.25)
                    .tint(Color.hubPrimary)

                if quantity > 1 && estimatedPrice > 0 {
                    HStack {
                        Text("Line total")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Spacer()
                        Text("$\(String(format: "%.2f", Double(quantity) * estimatedPrice))")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentGreen)
                    }
                }
            }

            EntryFormSection(title: "Priority") {
                Picker("Priority", selection: $priority) {
                    ForEach(GroceryPriority.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            EntryFormSection(title: "Notes") {
                TextField("Optional notes...", text: $notes, axis: .vertical)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(2...4)
            }
        }
    }
}