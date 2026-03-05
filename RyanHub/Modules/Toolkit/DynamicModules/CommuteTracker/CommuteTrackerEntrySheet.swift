import SwiftUI

struct CommuteTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CommuteTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedDirection: CommuteDirection = .toWork
    @State private var inputDurationminutes: Int = 1
    @State private var selectedTransportmode: TransportMode = .car
    @State private var selectedRoutelabel: RouteLabel = .primary
    @State private var inputDeparturetime: Date = Date()
    @State private var selectedTrafficcondition: TrafficCondition = .clear
    @State private var inputCostcents: Int = 1
    @State private var inputStresslevel: Double = 5
    @State private var inputUsedecomode: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Commute Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CommuteTrackerEntry(direction: selectedDirection, durationMinutes: inputDurationminutes, transportMode: selectedTransportmode, routeLabel: selectedRoutelabel, departureTime: inputDeparturetime, trafficCondition: selectedTrafficcondition, costCents: inputCostcents, stressLevel: Int(inputStresslevel), usedEcoMode: inputUsedecomode, notes: inputNotes)
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

                EntryFormSection(title: "Transport Mode") {
                    Picker("Transport Mode", selection: $selectedTransportmode) {
                        ForEach(TransportMode.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Route") {
                    Picker("Route", selection: $selectedRoutelabel) {
                        ForEach(RouteLabel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Departure Time") {
                    DatePicker("Departure Time", selection: $inputDeparturetime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Traffic") {
                    Picker("Traffic", selection: $selectedTrafficcondition) {
                        ForEach(TrafficCondition.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Cost ($)") {
                    Stepper("\(inputCostcents) cost ($)", value: $inputCostcents, in: 0...9999)
                }

                EntryFormSection(title: "Stress Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputStresslevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputStresslevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Eco-Friendly") {
                    Toggle("Eco-Friendly", isOn: $inputUsedecomode)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
