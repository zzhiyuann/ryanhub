import SwiftUI

struct SubscriptionTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SubscriptionTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputServicename: String = ""
    @State private var inputAmount: Double = 1.0
    @State private var selectedBillingcycle: BillingCycle = .weekly
    @State private var selectedCategory: SubscriptionCategory = .entertainment
    @State private var inputNextrenewaldate: Date = Date()
    @State private var inputUsagerating: Double = 5
    @State private var inputIsactive: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Subscription Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SubscriptionTrackerEntry(serviceName: inputServicename, amount: inputAmount, billingCycle: selectedBillingcycle, category: selectedCategory, nextRenewalDate: inputNextrenewaldate, usageRating: Int(inputUsagerating), isActive: inputIsactive, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Service Name") {
                    HubTextField(placeholder: "Service Name", text: $inputServicename)
                }

                EntryFormSection(title: "Amount per Cycle") {
                    Stepper(String(format: "$%.2f per cycle", inputAmount), value: $inputAmount, in: 0...9999, step: 1.0)
                }

                EntryFormSection(title: "Billing Cycle") {
                    Picker("Billing Cycle", selection: $selectedBillingcycle) {
                        ForEach(BillingCycle.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SubscriptionCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Next Renewal Date") {
                    DatePicker("Next Renewal Date", selection: $inputNextrenewaldate, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "How Much You Use It") {
                    VStack {
                        HStack {
                            Text("\(Int(inputUsagerating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputUsagerating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Currently Active") {
                    Toggle("Currently Active", isOn: $inputIsactive)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
