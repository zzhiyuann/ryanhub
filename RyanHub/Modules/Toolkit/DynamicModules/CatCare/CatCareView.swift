import SwiftUI

struct CatCareView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CatCareViewModel()
    @State private var inputEventtype: String = ""
    @State private var inputTimestamp: String = ""
    @State private var inputFoodname: String = ""
    @State private var inputPortiongrams: String = ""
    @State private var inputVetclinic: String = ""
    @State private var inputVetreason: String = ""
    @State private var inputNextvisitdue: String = ""
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
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cat Care")
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
                    TextField("Event Type", text: $inputEventtype)
                        .textFieldStyle(.roundedBorder)
                    TextField("Date & Time", text: $inputTimestamp)
                        .textFieldStyle(.roundedBorder)
                    TextField("Food / Brand", text: $inputFoodname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Portion (g)", text: $inputPortiongrams)
                        .textFieldStyle(.roundedBorder)
                    TextField("Vet Clinic", text: $inputVetclinic)
                        .textFieldStyle(.roundedBorder)
                    TextField("Visit Reason", text: $inputVetreason)
                        .textFieldStyle(.roundedBorder)
                    TextField("Next Visit Due", text: $inputNextvisitdue)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = CatCareEntry(eventType: inputEventtype, timestamp: inputTimestamp, foodName: inputFoodname.isEmpty ? nil : inputFoodname, portionGrams: Double(inputPortiongrams), vetClinic: inputVetclinic.isEmpty ? nil : inputVetclinic, vetReason: inputVetreason.isEmpty ? nil : inputVetreason, nextVisitDue: inputNextvisitdue.isEmpty ? nil : inputNextvisitdue, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputEventtype = ""
                            inputTimestamp = ""
                            inputFoodname = ""
                            inputPortiongrams = ""
                            inputVetclinic = ""
                            inputVetreason = ""
                            inputNextvisitdue = ""
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
                                Text("Event Type: \(entry.eventType)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Date & Time: \(entry.timestamp)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.foodName { Text("Food / Brand: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.portionGrams { Text("Portion (g): \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.vetClinic { Text("Vet Clinic: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.vetReason { Text("Visit Reason: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.nextVisitDue { Text("Next Visit Due: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
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
