import SwiftUI

struct LearningTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: LearningTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputSubjectname: String = ""
    @State private var selectedCategory: LearningCategory = .technology
    @State private var selectedSessiontype: LearningSessionType = .lecture
    @State private var inputDurationminutes: Int = 1
    @State private var inputFocusrating: Double = 5
    @State private var inputProgresspercent: Double = 5
    @State private var inputKeytakeaway: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Learning Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = LearningTrackerEntry(subjectName: inputSubjectname, category: selectedCategory, sessionType: selectedSessiontype, durationMinutes: inputDurationminutes, focusRating: Int(inputFocusrating), progressPercent: Int(inputProgresspercent), keyTakeaway: inputKeytakeaway)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Subject / Course") {
                    HubTextField(placeholder: "Subject / Course", text: $inputSubjectname)
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

                EntryFormSection(title: "Focus Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputFocusrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputFocusrating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Course Progress %") {
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

                EntryFormSection(title: "Key Takeaway") {
                    HubTextField(placeholder: "Key Takeaway", text: $inputKeytakeaway)
                }
        }
    }
}
