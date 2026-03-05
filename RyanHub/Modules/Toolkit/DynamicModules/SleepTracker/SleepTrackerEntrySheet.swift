import SwiftUI

struct SleepTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SleepTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputBedtime: Date = Date()
    @State private var inputWaketime: Date = Date()
    @State private var inputSleephours: Double = 7.0
    @State private var inputQualityrating: Double = 5
    @State private var selectedWakeupmood: WakeUpMood = .energized
    @State private var selectedSleepfactor: SleepFactor = .none
    @State private var inputHaddreams: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Sleep Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SleepTrackerEntry(bedtime: inputBedtime, wakeTime: inputWaketime, sleepHours: inputSleephours, qualityRating: Int(inputQualityrating), wakeUpMood: selectedWakeupmood, sleepFactor: selectedSleepfactor, hadDreams: inputHaddreams, notes: inputNotes)
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

                EntryFormSection(title: "Hours Slept") {
                    Stepper(String(format: "%.1f hours slept", inputSleephours), value: $inputSleephours, in: 0...24, step: 0.5)
                }

                EntryFormSection(title: "Sleep Quality (1–5)") {
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
                    Picker("Wake-Up Mood", selection: $selectedWakeupmood) {
                        ForEach(WakeUpMood.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Primary Factor") {
                    Picker("Primary Factor", selection: $selectedSleepfactor) {
                        ForEach(SleepFactor.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Had Dreams") {
                    Toggle("Had Dreams", isOn: $inputHaddreams)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
