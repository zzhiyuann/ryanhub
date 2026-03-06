import SwiftUI

// MARK: - Medications List View

struct MedicationTrackerMedicationsView: View {
    let viewModel: MedicationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEntrySheet = false
    @State private var editingEntry: MedicationTrackerEntry?

    private var activeMedications: [MedicationTrackerEntry] {
        viewModel.entries.filter { $0.isActive }
    }

    private var inactiveMedications: [MedicationTrackerEntry] {
        viewModel.entries.filter { !$0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    if !activeMedications.isEmpty {
                        medicationSection(
                            title: "Active",
                            medications: activeMedications
                        )
                    }

                    if !inactiveMedications.isEmpty {
                        medicationSection(
                            title: "Inactive",
                            medications: inactiveMedications
                        )
                    }
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingEntry = nil
                    showEntrySheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.hubPrimary)
                }
            }
        }
        .sheet(isPresented: $showEntrySheet) {
            MedicationTrackerMedicationEntrySheet(viewModel: viewModel)
        }
        .onChange(of: editingEntry) { _, newValue in
            if newValue != nil {
                showEntrySheet = true
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func medicationSection(title: String, medications: [MedicationTrackerEntry]) -> some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: title)

            ForEach(medications) { medication in
                MedicationRow(
                    medication: medication,
                    colorScheme: colorScheme,
                    onTap: {
                        editingEntry = medication
                    },
                    onToggleActive: {
                        toggleActive(medication)
                    },
                    onDelete: {
                        Task { await viewModel.deleteEntry(medication) }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Spacer().frame(height: 60)

            Image(systemName: "pill.fill")
                .font(.system(size: 48))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))

            Text("No Medications")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Tap + to add your first medication")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func toggleActive(_ medication: MedicationTrackerEntry) {
        var updated = medication
        updated.id = UUID().uuidString
        updated.isActive.toggle()
        Task {
            await viewModel.deleteEntry(medication)
            await viewModel.addEntry(updated)
        }
    }
}

// MARK: - Medication Row

private struct MedicationRow: View {
    let medication: MedicationTrackerEntry
    let colorScheme: ColorScheme
    let onTap: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HubCard {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Color dot
                    Circle()
                        .fill(medication.colorValue)
                        .frame(width: 12, height: 12)

                    // Name + dosage
                    VStack(alignment: .leading, spacing: 2) {
                        Text(medication.name.isEmpty ? "Unnamed" : medication.name)
                            .font(.hubBody)
                            .fontWeight(.medium)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        if !medication.dosage.isEmpty {
                            Text(medication.dosage)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Spacer()

                    // Form icon
                    Image(systemName: medication.form.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    // Frequency badge
                    Text(medication.frequency.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.hubPrimary.opacity(0.12))
                        .clipShape(Capsule())

                    // Supply gauge
                    supplyGauge
                }
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onToggleActive()
            } label: {
                Label(
                    medication.isActive ? "Deactivate" : "Activate",
                    systemImage: medication.isActive ? "pause.circle" : "play.circle"
                )
            }
            .tint(medication.isActive ? .orange : Color.hubAccentGreen)
        }
    }

    @ViewBuilder
    private var supplyGauge: some View {
        let days = medication.estimatedSupplyDays
        let isLow = medication.isLowSupply
        let maxDays: Double = 90
        let progress = min(Double(days) / maxDays, 1.0)

        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if isLow {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.hubAccentRed)
                }
                Text("\(days)d")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLow ? Color.hubAccentRed : AdaptiveColors.textSecondary(for: colorScheme))
            }

            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.15))

                    Capsule()
                        .fill(isLow ? Color.hubAccentRed : Color.hubAccentGreen)
                        .frame(width: max(4, 40 * progress))
                }
            }
            .frame(width: 40, height: 4)
        }
    }
}