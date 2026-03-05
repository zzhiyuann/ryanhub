import SwiftUI

struct CatCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: CatCareTrackerViewModel
    var onSave: (() -> Void)?

    @State private var eventType: EventType = .feeding
    @State private var feedType: FeedType = .wetFood
    @State private var portionSize: Double = 100.0
    @State private var catWeight: Double = 10.0
    @State private var vetReason: VetReason = .routine
    @State private var symptomType: SymptomType = .vomiting
    @State private var catMood: CatMood = .calm
    @State private var cost: Double = 0.0
    @State private var medicationName: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()

    var body: some View {
        QuickEntrySheet(
            title: "Add Cat Care Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: saveEntry
        ) {
            eventTypeSection
            eventDetailSection
            moodSection
            dateSection
            notesSection
        }
    }

    // MARK: - Sections

    private var eventTypeSection: some View {
        EntryFormSection(title: "Event Type") {
            Picker("Event Type", selection: $eventType) {
                ForEach(EventType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    @ViewBuilder
    private var eventDetailSection: some View {
        switch eventType {
        case .feeding:
            EntryFormSection(title: "Feeding Details") {
                Picker("Feed Type", selection: $feedType) {
                    ForEach(FeedType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                labeledSlider(
                    label: "Portion Size",
                    value: $portionSize,
                    range: 10...500,
                    step: 5,
                    display: "\(Int(portionSize))g"
                )
            }

        case .vetVisit:
            EntryFormSection(title: "Vet Visit Details") {
                Picker("Reason", selection: $vetReason) {
                    ForEach(VetReason.allCases) { reason in
                        Label(reason.displayName, systemImage: reason.icon).tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                labeledSlider(
                    label: "Cost",
                    value: $cost,
                    range: 0...1000,
                    step: 10,
                    display: "$\(String(format: "%.0f", cost))"
                )
            }

        case .weightCheck:
            EntryFormSection(title: "Weight") {
                labeledSlider(
                    label: "Cat Weight",
                    value: $catWeight,
                    range: 1...30,
                    step: 0.1,
                    display: "\(String(format: "%.1f", catWeight)) lbs"
                )
            }

        case .medication:
            EntryFormSection(title: "Medication Details") {
                HubTextField(placeholder: "Medication Name", text: $medicationName)

                labeledSlider(
                    label: "Cost",
                    value: $cost,
                    range: 0...500,
                    step: 5,
                    display: "$\(String(format: "%.0f", cost))"
                )
            }

        case .symptom:
            EntryFormSection(title: "Symptom") {
                Picker("Symptom Type", selection: $symptomType) {
                    ForEach(SymptomType.allCases) { symptom in
                        Label(symptom.displayName, systemImage: symptom.icon).tag(symptom)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    private var moodSection: some View {
        EntryFormSection(title: "Cat Mood") {
            Picker("Mood", selection: $catMood) {
                ForEach(CatMood.allCases) { mood in
                    Label(mood.displayName, systemImage: mood.icon).tag(mood)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    private var dateSection: some View {
        EntryFormSection(title: "Date & Time") {
            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    private var notesSection: some View {
        EntryFormSection(title: "Notes") {
            HubTextField(placeholder: "Add notes...", text: $notes)
        }
    }

    // MARK: - Helper Views

    private func labeledSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
                Text(display)
                    .font(.hubBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hubPrimary)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color.hubPrimary)
        }
    }

    // MARK: - Save

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var entry = CatCareTrackerEntry()
        entry.date = formatter.string(from: date)
        entry.eventType = eventType
        entry.feedType = feedType
        entry.portionSize = portionSize
        entry.catWeight = catWeight
        entry.vetReason = vetReason
        entry.symptomType = symptomType
        entry.catMood = catMood
        entry.cost = cost
        entry.medicationName = medicationName
        entry.notes = notes

        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}