import SwiftUI

struct PeopleJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PeopleJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputPersonname: String = ""
    @State private var selectedRelationship: RelationshipType = .colleague
    @State private var selectedMeetingcontext: MeetingContext = .coffee
    @State private var inputLocation: String = ""
    @State private var inputTopics: String = ""
    @State private var inputConnectionstrength: Double = 5
    @State private var selectedInteractionmood: InteractionMood = .great
    @State private var inputFollowupneeded: Bool = false
    @State private var inputFollowupnote: String = ""
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add People Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = PeopleJournalEntry(personName: inputPersonname, relationship: selectedRelationship, meetingContext: selectedMeetingcontext, location: inputLocation, topics: inputTopics, connectionStrength: Int(inputConnectionstrength), interactionMood: selectedInteractionmood, followUpNeeded: inputFollowupneeded, followUpNote: inputFollowupnote, notes: inputNotes)
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

                EntryFormSection(title: "How You Met / Context") {
                    Picker("How You Met / Context", selection: $selectedMeetingcontext) {
                        ForEach(MeetingContext.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Location") {
                    HubTextField(placeholder: "Location", text: $inputLocation)
                }

                EntryFormSection(title: "Topics Discussed") {
                    HubTextField(placeholder: "Topics Discussed", text: $inputTopics)
                }

                EntryFormSection(title: "Connection Strength") {
                    VStack {
                        HStack {
                            Text("\(Int(inputConnectionstrength))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputConnectionstrength, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Interaction Vibe") {
                    Picker("Interaction Vibe", selection: $selectedInteractionmood) {
                        ForEach(InteractionMood.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Follow-up Needed") {
                    Toggle("Follow-up Needed", isOn: $inputFollowupneeded)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Follow-up Note") {
                    HubTextField(placeholder: "Follow-up Note", text: $inputFollowupnote)
                }

                EntryFormSection(title: "Quick Notes") {
                    HubTextField(placeholder: "Quick Notes", text: $inputNotes)
                }
        }
    }
}
