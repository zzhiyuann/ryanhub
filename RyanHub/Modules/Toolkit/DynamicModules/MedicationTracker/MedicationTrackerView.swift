import SwiftUI

struct MedicationTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = MedicationTrackerViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Medication Tracker")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                    Text("Today").tag(0)
                    Text("My Meds").tag(1)
                    Text("Adherence").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {
                    if selectedTab == 0 {
                        MedicationTrackerTodayView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        MedicationTrackerMedicationsView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        MedicationTrackerAdherenceView(viewModel: viewModel)
                    }

            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) {
            MedicationTrackerMedicationEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }
}
