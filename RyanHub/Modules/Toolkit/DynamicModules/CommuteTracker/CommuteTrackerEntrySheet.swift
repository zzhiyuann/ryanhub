import SwiftUI

struct CommuteTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CommuteTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedDirection: CommuteDirection = .toWork
    @State private var inputDurationminutes: Int = 1
    @State private var selectedTransportmode: TransportMode = .car
    @State private var inputRoutename: String = ""
    @State private var inputDeparturetime: Date = Date()
    @State private var inputDistancemiles: Double = 0.0
    @State private var selectedTrafficlevel: TrafficLevel = .light
    @State private var inputCost: Double = 0.0
    @State private var inputStressrating: Double = 5
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Commute Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CommuteTrackerEntry(direction: selectedDirection, durationMinutes: inputDurationminutes, transportMode: selectedTransportmode, routeName: inputRoutename, departureTime: inputDeparturetime, distanceMiles: inputDistancemiles, trafficLevel: selectedTrafficlevel, cost: inputCost, stressRating: Int(inputStressrating), notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Direction") {
                    Picker("Direction", selection: $selectedDirection) {
                        ForEach(CommuteDirection.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDurationminutes) duration (min)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Transport") {
                    Picker("Transport", selection: $selectedTransportmode) {
                        ForEach(TransportMode.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Route") {
                    HubTextField(placeholder: "Route", text: $inputRoutename)
                }

                EntryFormSection(title: "Departure Time") {
                    DatePicker("Departure Time", selection: $inputDeparturetime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Distance (mi)") {
                    Stepper("\(inputDistancemiles) distance (mi)", value: $inputDistancemiles, in: 0...9999)
                }

                EntryFormSection(title: "Traffic") {
                    Picker("Traffic", selection: $selectedTrafficlevel) {
                        ForEach(TrafficLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Cost ($)") {
                    Stepper("\(inputCost) cost ($)", value: $inputCost, in: 0...9999)
                }

                EntryFormSection(title: "Stress Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputStressrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputStressrating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
