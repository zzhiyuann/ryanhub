import SwiftUI

struct CoffeeTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CoffeeTrackerViewModel()
    @State private var inputCupcount: String = ""
    @State private var inputDrinktype: String = ""
    @State private var inputCaffeinepercup: String = ""
    @State private var inputTotalcaffeine: String = ""
    @State private var inputLoggedat: String = ""
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
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coffee Tracker")
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
                    TextField("Cups", text: $inputCupcount)
                        .textFieldStyle(.roundedBorder)
                    TextField("Drink Type", text: $inputDrinktype)
                        .textFieldStyle(.roundedBorder)
                    TextField("Caffeine per Cup (mg)", text: $inputCaffeinepercup)
                        .textFieldStyle(.roundedBorder)
                    TextField("Total Caffeine (mg)", text: $inputTotalcaffeine)
                        .textFieldStyle(.roundedBorder)
                    TextField("Time", text: $inputLoggedat)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = CoffeeTrackerEntry(cupCount: Int(inputCupcount) ?? 0, drinkType: inputDrinktype, caffeinePerCup: Double(inputCaffeinepercup) ?? 0, totalCaffeine: Double(inputTotalcaffeine) ?? 0, loggedAt: inputLoggedat, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputCupcount = ""
                            inputDrinktype = ""
                            inputCaffeinepercup = ""
                            inputTotalcaffeine = ""
                            inputLoggedat = ""
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
                                Text("Cups: \(entry.cupCount)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Drink Type: \(entry.drinkType)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Caffeine per Cup (mg): \(entry.caffeinePerCup)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Total Caffeine (mg): \(entry.totalCaffeine)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Time: \(entry.loggedAt)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
