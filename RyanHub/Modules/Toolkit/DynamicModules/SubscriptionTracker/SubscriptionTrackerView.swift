import SwiftUI

struct SubscriptionTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SubscriptionTrackerViewModel()
    @State private var inputServicename: String = ""
    @State private var inputMonthlycost: String = ""
    @State private var inputBillingcycle: String = ""
    @State private var inputNextbillingdate: String = ""
    @State private var inputCategory: String = ""
    @State private var inputIsactive: String = ""
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
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subscription Tracker")
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
                    TextField("Service Name", text: $inputServicename)
                        .textFieldStyle(.roundedBorder)
                    TextField("Monthly Cost", text: $inputMonthlycost)
                        .textFieldStyle(.roundedBorder)
                    TextField("Billing Cycle", text: $inputBillingcycle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Next Billing Date", text: $inputNextbillingdate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Category", text: $inputCategory)
                        .textFieldStyle(.roundedBorder)
                    TextField("Active", text: $inputIsactive)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = SubscriptionTrackerEntry(serviceName: inputServicename, monthlyCost: Double(inputMonthlycost) ?? 0, billingCycle: inputBillingcycle, nextBillingDate: inputNextbillingdate, category: inputCategory, isActive: inputIsactive == "true", note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputServicename = ""
                            inputMonthlycost = ""
                            inputBillingcycle = ""
                            inputNextbillingdate = ""
                            inputCategory = ""
                            inputIsactive = ""
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
                                Text("Service Name: \(entry.serviceName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Monthly Cost: \(entry.monthlyCost)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Billing Cycle: \(entry.billingCycle)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Next Billing Date: \(entry.nextBillingDate)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Category: \(entry.category)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Active: \(entry.isActive)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
