import SwiftUI

struct LearningTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: LearningTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputSkillname: String = ""
    @State private var selectedCategory: LearningCategory = .programming
    @State private var selectedSessiontype: LearningSessionType = .videoLecture
    @State private var inputDurationminutes: Int = 1
    @State private var inputProgresspercent: Double = 5
    @State private var inputConfidencerating: Double = 5
    @State private var inputMilestone: String = ""
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Learning Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = LearningTrackerEntry(skillName: inputSkillname, category: selectedCategory, sessionType: selectedSessiontype, durationMinutes: inputDurationminutes, progressPercent: Int(inputProgresspercent), confidenceRating: Int(inputConfidencerating), milestone: inputMilestone, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Skill / Course") {
                    HubTextField(placeholder: "Skill / Course", text: $inputSkillname)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(LearningCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Session Type") {
                    Picker("Session Type", selection: $selectedSessiontype) {
                        ForEach(LearningSessionType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDurationminutes) duration (min)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Overall Progress (%)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputProgresspercent))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputProgresspercent, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Confidence (1–5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputConfidencerating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputConfidencerating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Milestone Reached") {
                    HubTextField(placeholder: "Milestone Reached", text: $inputMilestone)
                }

                EntryFormSection(title: "Key Takeaways") {
                    HubTextField(placeholder: "Key Takeaways", text: $inputNotes)
                }
        }
    }
}
