import SwiftUI

struct MedicationTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = MedicationTrackerViewModel()
    @State private var inputMedicationname: String = ""
    @State private var inputDosage: String = ""
    @State private var inputFrequency: String = ""
    @State private var inputScheduledtime: String = ""
    @State private var inputTaken: String = ""
    @State private var inputRefilldate: String = ""
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
                        Image(systemName: "pill.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Medication Tracker")
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
                    TextField("Medication Name", text: $inputMedicationname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Dosage", text: $inputDosage)
                        .textFieldStyle(.roundedBorder)
                    TextField("Frequency", text: $inputFrequency)
                        .textFieldStyle(.roundedBorder)
                    TextField("Scheduled Time", text: $inputScheduledtime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Taken Today", text: $inputTaken)
                        .textFieldStyle(.roundedBorder)
                    TextField("Refill Date", text: $inputRefilldate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = MedicationTrackerEntry(medicationName: inputMedicationname, dosage: inputDosage, frequency: inputFrequency, scheduledTime: inputScheduledtime, taken: inputTaken == "true", refillDate: inputRefilldate.isEmpty ? nil : inputRefilldate, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputMedicationname = ""
                            inputDosage = ""
                            inputFrequency = ""
                            inputScheduledtime = ""
                            inputTaken = ""
                            inputRefilldate = ""
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
                                Text("Medication Name: \(entry.medicationName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Dosage: \(entry.dosage)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Frequency: \(entry.frequency)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Scheduled Time: \(entry.scheduledTime)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Taken Today: \(entry.taken)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.refillDate { Text("Refill Date: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.note { Text("Notes: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
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
