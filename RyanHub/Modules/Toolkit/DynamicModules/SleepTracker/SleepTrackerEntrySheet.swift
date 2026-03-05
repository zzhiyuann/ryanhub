import SwiftUI

struct SleepTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SleepTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputBedtime: Date = Date()
    @State private var inputWaketime: Date = Date()
    @State private var inputQualityrating: Double = 5
    @State private var selectedWakemood: WakeMood = .energized
    @State private var selectedPresleepactivity: PreSleepActivity = .reading
    @State private var inputDreamsrecalled: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Sleep Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SleepTrackerEntry(bedtime: inputBedtime, wakeTime: inputWaketime, qualityRating: Int(inputQualityrating), wakeMood: selectedWakemood, preSleepActivity: selectedPresleepactivity, dreamsRecalled: inputDreamsrecalled, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Bedtime") {
                    DatePicker("Bedtime", selection: $inputBedtime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Wake Time") {
                    DatePicker("Wake Time", selection: $inputWaketime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Sleep Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputQualityrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputQualityrating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Wake-Up Mood") {
                    Picker("Wake-Up Mood", selection: $selectedWakemood) {
                        ForEach(WakeMood.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Pre-Sleep Activity") {
                    Picker("Pre-Sleep Activity", selection: $selectedPresleepactivity) {
                        ForEach(PreSleepActivity.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Remembered Dreams") {
                    Toggle("Remembered Dreams", isOn: $inputDreamsrecalled)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
