import SwiftUI

struct PeopleNotesEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PeopleNotesViewModel
    var onSave: (() -> Void)?
    @State private var inputPersonname: String = ""
    @State private var selectedRelationship: RelationshipType = .colleague
    @State private var selectedMeetingcontext: MeetingContext = .inPerson
    @State private var inputLocation: String = ""
    @State private var inputTopics: String = ""
    @State private var inputFollowup: String = ""
    @State private var inputFollowupdone: Bool = false
    @State private var inputConnectionrating: Double = 5
    @State private var selectedInteractionmood: InteractionMood = .great
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add People Notes",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = PeopleNotesEntry(personName: inputPersonname, relationship: selectedRelationship, meetingContext: selectedMeetingcontext, location: inputLocation, topics: inputTopics, followUp: inputFollowup, followUpDone: inputFollowupdone, connectionRating: Int(inputConnectionrating), interactionMood: selectedInteractionmood, notes: inputNotes)
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

                EntryFormSection(title: "How You Connected") {
                    Picker("How You Connected", selection: $selectedMeetingcontext) {
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

                EntryFormSection(title: "Follow-up Action") {
                    HubTextField(placeholder: "Follow-up Action", text: $inputFollowup)
                }

                EntryFormSection(title: "Follow-up Complete") {
                    Toggle("Follow-up Complete", isOn: $inputFollowupdone)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Connection Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputConnectionrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputConnectionrating, in: 1...10, step: 1)
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

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
