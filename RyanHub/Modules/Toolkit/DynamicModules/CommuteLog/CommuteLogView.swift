import SwiftUI

struct CommuteLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CommuteLogViewModel()
    @State private var inputDeparturetime: String = ""
    @State private var inputArrivaltime: String = ""
    @State private var inputDurationminutes: String = ""
    @State private var inputOrigin: String = ""
    @State private var inputDestination: String = ""
    @State private var inputTransportmode: String = ""
    @State private var inputDistancekm: String = ""
    @State private var inputNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "car.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Commute Log")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\(viewModel.entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                }

                // Add entry form
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Add Entry")
                    TextField("Departure Time", text: $inputDeparturetime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Arrival Time", text: $inputArrivaltime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Duration (min)", text: $inputDurationminutes)
                        .textFieldStyle(.roundedBorder)
                    TextField("Starting Point", text: $inputOrigin)
                        .textFieldStyle(.roundedBorder)
                    TextField("Destination", text: $inputDestination)
                        .textFieldStyle(.roundedBorder)
                    TextField("Transport Mode", text: $inputTransportmode)
                        .textFieldStyle(.roundedBorder)
                    TextField("Distance (km)", text: $inputDistancekm)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = CommuteLogEntry(departureTime: inputDeparturetime, arrivalTime: inputArrivaltime, durationMinutes: Double(inputDurationminutes) ?? 0, origin: inputOrigin, destination: inputDestination, transportMode: inputTransportmode, distanceKm: Double(inputDistancekm), note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputDeparturetime = ""
                            inputArrivaltime = ""
                            inputDurationminutes = ""
                            inputOrigin = ""
                            inputDestination = ""
                            inputTransportmode = ""
                            inputDistancekm = ""
                            inputNote = ""
                        }
                    } label: {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: HubLayout.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(Color.hubPrimary)
                            )
                    }
                }
                .padding(HubLayout.standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )

                // Entries list
                if !viewModel.entries.isEmpty {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Recent Entries")
                        ForEach(viewModel.entries.reversed()) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("Departure Time: \(entry.departureTime)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Arrival Time: \(entry.arrivalTime)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Duration (min): \(entry.durationMinutes)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Starting Point: \(entry.origin)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Destination: \(entry.destination)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Transport Mode: \(entry.transportMode)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.distanceKm { Text("Distance (km): \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.note { Text("Note: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                }
                                Spacer()
                                Button {
                                    Task { await viewModel.deleteEntry(entry) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.hubAccentRed)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AdaptiveColors.surface(for: colorScheme))
                            )
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
