import SwiftUI

struct LearningTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: LearningTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputSubject: String = ""
    @State private var selectedCategory: LearningCategory = .programming
    @State private var inputDurationminutes: Int = 1
    @State private var selectedResourcetype: ResourceType = .onlineCourse
    @State private var inputResourcename: String = ""
    @State private var inputConfidencelevel: Double = 5
    @State private var inputCompletionpercent: Double = 5
    @State private var inputSessiongoalmet: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Learning Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = LearningTrackerEntry(subject: inputSubject, category: selectedCategory, durationMinutes: inputDurationminutes, resourceType: selectedResourcetype, resourceName: inputResourcename, confidenceLevel: Int(inputConfidencelevel), completionPercent: Int(inputCompletionpercent), sessionGoalMet: inputSessiongoalmet, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Subject / Skill") {
                    HubTextField(placeholder: "Subject / Skill", text: $inputSubject)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(LearningCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDurationminutes) duration (min)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Resource Type") {
                    Picker("Resource Type", selection: $selectedResourcetype) {
                        ForEach(ResourceType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Resource Name") {
                    HubTextField(placeholder: "Resource Name", text: $inputResourcename)
                }

                EntryFormSection(title: "Confidence Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputConfidencelevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputConfidencelevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Completion %") {
                    VStack {
                        HStack {
                            Text("\(Int(inputCompletionpercent))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputCompletionpercent, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Session Goal Met") {
                    Toggle("Session Goal Met", isOn: $inputSessiongoalmet)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
