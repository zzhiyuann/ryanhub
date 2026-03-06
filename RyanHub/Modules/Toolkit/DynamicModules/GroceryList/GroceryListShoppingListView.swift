import SwiftUI

struct GroceryListShoppingListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GroceryListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The primary grocery checklist — the only view users need. Top section has an inline text field with a '+' button for rapid item entry; typing a name auto-suggests a category (e.g., 'milk' → Dairy). Below that, a slim progress bar shows 'X of Y items' with a fill animation. Items are grouped into collapsible sections by GroceryCategory, each with a colored category icon header. Each item row displays a circular checkbox, item name, and a subtle 'qty × unit' badge on the trailing side. Tapping an item toggles its checked state: checked items get a strikethrough animation, dim to 50% opacity, and slide down into a collapsible 'In Cart' section at the bottom. Swipe left to delete an item, long-press to edit quantity/unit/notes in a compact popover. When all items are checked, a celebratory checkmark animation plays with a 'Clear Cart' button that archives the trip and resets the list. Empty state shows a cart illustration with 'Your list is empty — start adding items above.'")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
                ForEach(viewModel.entries) { entry in
                    HubCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.summaryLine)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text(entry.date)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}
