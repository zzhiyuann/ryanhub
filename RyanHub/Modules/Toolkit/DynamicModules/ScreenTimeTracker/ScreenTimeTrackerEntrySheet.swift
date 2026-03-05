import SwiftUI

struct ScreenTimeTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ScreenTimeTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputDuration: Double = 0.5
    @State private var selectedCategory: ScreenCategory = .socialMedia
    @State private var selectedIntentionality: UsageIntent = .intentional
    @State private var selectedDevice: DeviceType = .phone
    @State private var inputAppname: String = ""
    @State private var inputNote: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Screen Time Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = ScreenTimeTrackerEntry(duration: inputDuration, category: selectedCategory, intentionality: selectedIntentionality, device: selectedDevice, appName: inputAppname, note: inputNote)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Duration (hours)") {
                    Stepper(String(format: "%.1f hours", inputDuration), value: $inputDuration, in: 0...24, step: 0.5)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ScreenCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Usage Type") {
                    Picker("Usage Type", selection: $selectedIntentionality) {
                        ForEach(UsageIntent.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Device") {
                    Picker("Device", selection: $selectedDevice) {
                        ForEach(DeviceType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "App or Activity") {
                    HubTextField(placeholder: "App or Activity", text: $inputAppname)
                }

                EntryFormSection(title: "Note") {
                    HubTextField(placeholder: "Note", text: $inputNote)
                }
        }
    }
}
