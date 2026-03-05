import SwiftUI

struct PeopleNotesEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PeopleNotesViewModel
    var onSave: (() -> Void)?
    @State private var inputPersonname: String = ""
    @State private var selectedRelationship: RelationshipType = .colleague
    @State private var selectedMeetingtype: MeetingType = .coffee
    @State private var inputLocation: String = ""
    @State private var inputTopics: String = ""
    @State private var inputInteractionquality: Double = 5
    @State private var selectedEnergylevel: EnergyLevel = .inspiring
    @State private var inputFollowupneeded: Bool = false
    @State private var inputFollowupnote: String = ""
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add People Notes",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = PeopleNotesEntry(personName: inputPersonname, relationship: selectedRelationship, meetingType: selectedMeetingtype, location: inputLocation, topics: inputTopics, interactionQuality: Int(inputInteractionquality), energyLevel: selectedEnergylevel, followUpNeeded: inputFollowupneeded, followUpNote: inputFollowupnote, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Person Name") {
                    HubTextField(placeholder: "Person Name", text: $inputPersonname)
                }

                EntryFormSection(title: "Relationship") {
                    Picker("Relationship", selection: $selectedRelationship) {
                        ForEach(RelationshipType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Meeting Type") {
                    Picker("Meeting Type", selection: $selectedMeetingtype) {
                        ForEach(MeetingType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Where / Context") {
                    HubTextField(placeholder: "Where / Context", text: $inputLocation)
                }

                EntryFormSection(title: "What You Discussed") {
                    HubTextField(placeholder: "What You Discussed", text: $inputTopics)
                }

                EntryFormSection(title: "Interaction Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputInteractionquality))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputInteractionquality, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Their Energy") {
                    Picker("Their Energy", selection: $selectedEnergylevel) {
                        ForEach(EnergyLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Follow-up Needed") {
                    Toggle("Follow-up Needed", isOn: $inputFollowupneeded)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Follow-up Action") {
                    HubTextField(placeholder: "Follow-up Action", text: $inputFollowupnote)
                }

                EntryFormSection(title: "Private Notes") {
                    HubTextField(placeholder: "Private Notes", text: $inputNotes)
                }
        }
    }
}
