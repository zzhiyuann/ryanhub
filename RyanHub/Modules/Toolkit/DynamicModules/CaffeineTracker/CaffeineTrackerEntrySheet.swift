import SwiftUI

struct CaffeineTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CaffeineTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedDrinktype: CoffeeDrinkType = .espresso
    @State private var selectedSize: DrinkSize = .small
    @State private var inputCaffeinemg: Int = 1
    @State private var inputTime: Date = Date()
    @State private var inputRating: Double = 5
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Caffeine Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CaffeineTrackerEntry(drinkType: selectedDrinktype, size: selectedSize, caffeineMg: inputCaffeinemg, time: inputTime, rating: Int(inputRating), notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Drink Type") {
                    Picker("Drink Type", selection: $selectedDrinktype) {
                        ForEach(CoffeeDrinkType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Size") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(DrinkSize.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Caffeine (mg)") {
                    Stepper("\(inputCaffeinemg) caffeine (mg)", value: $inputCaffeinemg, in: 0...9999)
                }

                EntryFormSection(title: "Time") {
                    DatePicker("Time", selection: $inputTime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Enjoyment") {
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
        }
    }
}
