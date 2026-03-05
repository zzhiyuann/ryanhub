import SwiftUI

struct CommuteTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CommuteTrackerViewModel
    var onSave: (() -> Void)?

    @State private var entry = CommuteTrackerEntry()
    @State private var costDollars: Double = 0.0

    var body: some View {
        QuickEntrySheet(
            title: "Add Commute Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                entry.costCents = Int((costDollars * 100).rounded())
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {
            EntryFormSection(title: "Trip Details") {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Direction")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Picker("Direction", selection: $entry.direction) {
                        ForEach(CommuteDirection.allCases) { dir in
                            Label(dir.displayName, systemImage: dir.icon).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Transport Mode")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Picker("Transport Mode", selection: $entry.transportMode) {
                        ForEach(TransportMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("Route name (optional)", text: $entry.routeName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Duration & Timing") {
                Stepper(
                    "Duration: \(entry.formattedDuration)",
                    value: $entry.durationMinutes,
                    in: 1...300,
                    step: 5
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                DatePicker(
                    "Departure Time",
                    selection: $entry.departureTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Stepper(
                    "Delay: \(entry.delayMinutes) min",
                    value: $entry.delayMinutes,
                    in: 0...120,
                    step: 5
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Traffic & Experience") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Traffic Level")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(entry.trafficEmoji) \(entry.trafficLabel)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(entry.trafficLevel) },
                            set: { entry.trafficLevel = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .tint(Color.hubAccentYellow)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Experience")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(entry.experienceLabel)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(entry.experienceRating) },
                            set: { entry.experienceRating = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .tint(Color.hubAccentGreen)
                }
            }

            EntryFormSection(title: "Cost") {
                Stepper(
                    value: $costDollars,
                    in: 0...200,
                    step: 0.25
                ) {
                    HStack {
                        Text("Cost")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(costDollars == 0 ? "Free" : String(format: "$%.2f", costDollars))
                            .font(.hubBody)
                            .foregroundStyle(costDollars == 0 ? AdaptiveColors.textSecondary(for: colorScheme) : Color.hubPrimary)
                    }
                }
            }

            EntryFormSection(title: "Notes") {
                TextField("Add notes...", text: $entry.notes, axis: .vertical)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(3...6)
            }
        }
    }
}