import SwiftUI

struct ScreenTimeTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ScreenTimeTrackerViewModel()
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
                    Image(systemName: "hourglass.bottomhalf.filled")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Screen Time Tracker")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                    Text("Home").tag(0)
                    Text("History").tag(1)
                    Text("Analytics").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {
                    if selectedTab == 0 {
                        ScreenTimeTrackerDashboardView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        ScreenTimeTrackerHistoryView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        ScreenTimeTrackerAnalyticsView(viewModel: viewModel)
                    }

                // FAB
                QuickEntryFAB {
                    showAddSheet = true
                }
                .padding(HubLayout.standardPadding)
            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) {
            ScreenTimeTrackerEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }
}
