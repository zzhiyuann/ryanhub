import SwiftUI

struct ScreenTimeTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ScreenTimeTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputDurationminutes: Int = 1
    @State private var selectedCategory: ScreenCategory = .socialMedia
    @State private var inputAppname: String = ""
    @State private var inputWasintentional: Bool = false
    @State private var selectedDevicetype: DeviceType = .phone
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Screen Time Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = ScreenTimeTrackerEntry(durationMinutes: inputDurationminutes, category: selectedCategory, appName: inputAppname, wasIntentional: inputWasintentional, deviceType: selectedDevicetype, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Duration (minutes)") {
                    Stepper("\(inputDurationminutes) duration (minutes)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ScreenCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "App or Activity") {
                    HubTextField(placeholder: "App or Activity", text: $inputAppname)
                }

                EntryFormSection(title: "Intentional Use") {
                    Toggle("Intentional Use", isOn: $inputWasintentional)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Device") {
                    Picker("Device", selection: $selectedDevicetype) {
                        ForEach(DeviceType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
