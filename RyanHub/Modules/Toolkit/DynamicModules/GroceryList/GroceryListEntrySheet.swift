import SwiftUI

struct GroceryListEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GroceryListViewModel
    var onSave: (() -> Void)?
    @State private var inputItemname: String = ""
    @State private var selectedCategory: GroceryCategory = .produce
    @State private var inputQuantity: Int = 1
    @State private var selectedUnit: MeasurementUnit = .pieces
    @State private var inputEstimatedprice: Double = 0.0
    @State private var inputIschecked: Bool = false
    @State private var selectedPriority: ItemPriority = .essential
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Grocery List",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = GroceryListEntry(itemName: inputItemname, category: selectedCategory, quantity: inputQuantity, unit: selectedUnit, estimatedPrice: inputEstimatedprice, isChecked: inputIschecked, priority: selectedPriority, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Item Name") {
                    HubTextField(placeholder: "Item Name", text: $inputItemname)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(GroceryCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Quantity") {
                    Stepper("\(inputQuantity) quantity", value: $inputQuantity, in: 0...9999)
                }

                EntryFormSection(title: "Unit") {
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(MeasurementUnit.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Est. Price ($)") {
                    Stepper("\(inputEstimatedprice) est. price ($)", value: $inputEstimatedprice, in: 0...9999)
                }

                EntryFormSection(title: "Purchased") {
                    Toggle("Purchased", isOn: $inputIschecked)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(ItemPriority.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
