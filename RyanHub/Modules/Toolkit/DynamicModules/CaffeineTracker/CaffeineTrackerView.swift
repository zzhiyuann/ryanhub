import SwiftUI

struct CaffeineTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CaffeineTrackerViewModel()
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
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Caffeine Tracker")
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
                        CaffeineTrackerDashboardView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        CaffeineTrackerHistoryView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        CaffeineTrackerAnalyticsView(viewModel: viewModel)
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
            CaffeineTrackerEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }
}
