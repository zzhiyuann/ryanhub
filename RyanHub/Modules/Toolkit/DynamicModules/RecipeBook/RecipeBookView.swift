import SwiftUI

struct RecipeBookView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = RecipeBookViewModel()
    @State private var inputTitle: String = ""
    @State private var inputIngredients: String = ""
    @State private var inputPreptime: String = ""
    @State private var inputCooktime: String = ""
    @State private var inputServings: String = ""
    @State private var inputInstructions: String = ""
    @State private var inputCategory: String = ""
    @State private var inputNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recipe Book")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\(viewModel.entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                }

                // Add entry form
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Add Entry")
                    TextField("Recipe Name", text: $inputTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Ingredients", text: $inputIngredients)
                        .textFieldStyle(.roundedBorder)
                    TextField("Prep Time (min)", text: $inputPreptime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Cook Time (min)", text: $inputCooktime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Servings", text: $inputServings)
                        .textFieldStyle(.roundedBorder)
                    TextField("Instructions", text: $inputInstructions)
                        .textFieldStyle(.roundedBorder)
                    TextField("Category", text: $inputCategory)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = RecipeBookEntry(title: inputTitle, ingredients: inputIngredients, prepTime: Int(inputPreptime) ?? 0, cookTime: Int(inputCooktime) ?? 0, servings: Int(inputServings) ?? 0, instructions: inputInstructions, category: inputCategory, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputTitle = ""
                            inputIngredients = ""
                            inputPreptime = ""
                            inputCooktime = ""
                            inputServings = ""
                            inputInstructions = ""
                            inputCategory = ""
                            inputNote = ""
                        }
                    } label: {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: HubLayout.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(Color.hubPrimary)
                            )
                    }
                }
                .padding(HubLayout.standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )

                // Entries list
                if !viewModel.entries.isEmpty {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Recent Entries")
                        ForEach(viewModel.entries.reversed()) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("Recipe Name: \(entry.title)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Ingredients: \(entry.ingredients)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Prep Time (min): \(entry.prepTime)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Cook Time (min): \(entry.cookTime)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Servings: \(entry.servings)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Instructions: \(entry.instructions)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Category: \(entry.category)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.note { Text("Notes: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                }
                                Spacer()
                                Button {
                                    Task { await viewModel.deleteEntry(entry) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.hubAccentRed)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AdaptiveColors.surface(for: colorScheme))
                            )
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
