import SwiftUI

struct RecipeBoxEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel
    var onSave: (() -> Void)?
    @State private var inputName: String = ""
    @State private var selectedCategory: MealCategory = .breakfast
    @State private var selectedCuisine: CuisineType = .italian
    @State private var inputIngredients: String = ""
    @State private var inputServings: Int = 1
    @State private var inputPreptimeminutes: Int = 1
    @State private var inputCooktimeminutes: Int = 1
    @State private var selectedDifficulty: DifficultyLevel = .beginner
    @State private var inputRating: Double = 5
    @State private var inputNotes: String = ""
    @State private var inputIsfavorite: Bool = false
    @State private var inputTimescooked: Int = 1

    var body: some View {
        QuickEntrySheet(
            title: "Add Recipe Box",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = RecipeBoxEntry(name: inputName, category: selectedCategory, cuisine: selectedCuisine, ingredients: inputIngredients, servings: inputServings, prepTimeMinutes: inputPreptimeminutes, cookTimeMinutes: inputCooktimeminutes, difficulty: selectedDifficulty, rating: Int(inputRating), notes: inputNotes, isFavorite: inputIsfavorite, timesCooked: inputTimescooked)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Recipe Name") {
                    HubTextField(placeholder: "Recipe Name", text: $inputName)
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

                EntryFormSection(title: "Ingredients") {
                    HubTextField(placeholder: "Ingredients", text: $inputIngredients)
                }

                EntryFormSection(title: "Servings") {
                    Stepper("\(inputServings) servings", value: $inputServings, in: 0...9999)
                }

                EntryFormSection(title: "Prep Time (min)") {
                    Stepper("\(inputPreptimeminutes) prep time (min)", value: $inputPreptimeminutes, in: 0...9999)
                }

                EntryFormSection(title: "Cook Time (min)") {
                    Stepper("\(inputCooktimeminutes) cook time (min)", value: $inputCooktimeminutes, in: 0...9999)
                }

                EntryFormSection(title: "Difficulty") {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Rating") {
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

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }

                EntryFormSection(title: "Favorite") {
                    Toggle("Favorite", isOn: $inputIsfavorite)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Times Cooked") {
                    Stepper("\(inputTimescooked) times cooked", value: $inputTimescooked, in: 0...9999)
                }
        }
    }
}
