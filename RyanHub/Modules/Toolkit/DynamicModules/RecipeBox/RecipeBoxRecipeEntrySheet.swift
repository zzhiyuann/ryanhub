import SwiftUI

struct RecipeBoxRecipeEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel
    var onSave: (() -> Void)?
    @State private var inputTitle: String = ""
    @State private var selectedCategory: MealCategory = .breakfast
    @State private var selectedCuisine: CuisineType = .italian
    @State private var selectedDifficulty: DifficultyLevel = .easy
    @State private var inputPreptimeminutes: Int = 1
    @State private var inputCooktimeminutes: Int = 1
    @State private var inputServings: Int = 1
    @State private var inputIngredients: String = ""
    @State private var inputSteps: String = ""
    @State private var inputRating: Double = 5
    @State private var inputIsfavorite: Bool = false
    @State private var inputCookcount: Int = 1
    @State private var inputNotes: String = ""
    @State private var inputSourceurl: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Recipe Box",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let ingredientsList = inputIngredients.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                let stepsList = inputSteps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                let entry = RecipeBoxEntry(title: inputTitle, category: selectedCategory, cuisine: selectedCuisine, difficulty: selectedDifficulty, prepTimeMinutes: inputPreptimeminutes, cookTimeMinutes: inputCooktimeminutes, servings: inputServings, ingredients: ingredientsList, steps: stepsList, rating: Int(inputRating), isFavorite: inputIsfavorite, cookCount: inputCookcount, notes: inputNotes, sourceURL: inputSourceurl)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Recipe Name") {
                    HubTextField(placeholder: "Recipe Name", text: $inputTitle)
                }

                EntryFormSection(title: "Meal Category") {
                    Picker("Meal Category", selection: $selectedCategory) {
                        ForEach(MealCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Cuisine") {
                    Picker("Cuisine", selection: $selectedCuisine) {
                        ForEach(CuisineType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Difficulty") {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Prep Time (min)") {
                    Stepper("\(inputPreptimeminutes) prep time (min)", value: $inputPreptimeminutes, in: 0...9999)
                }

                EntryFormSection(title: "Cook Time (min)") {
                    Stepper("\(inputCooktimeminutes) cook time (min)", value: $inputCooktimeminutes, in: 0...9999)
                }

                EntryFormSection(title: "Servings") {
                    Stepper("\(inputServings) servings", value: $inputServings, in: 0...9999)
                }

                EntryFormSection(title: "Ingredients") {
                    HubTextField(placeholder: "Ingredients", text: $inputIngredients)
                }

                EntryFormSection(title: "Instructions") {
                    HubTextField(placeholder: "Instructions", text: $inputSteps)
                }

                EntryFormSection(title: "Rating (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputRating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputRating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Favorite") {
                    Toggle("Favorite", isOn: $inputIsfavorite)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Times Cooked") {
                    Stepper("\(inputCookcount) times cooked", value: $inputCookcount, in: 0...9999)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }

                EntryFormSection(title: "Source URL") {
                    HubTextField(placeholder: "Source URL", text: $inputSourceurl)
                }
        }
    }
}
