import SwiftUI

struct HabitTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HabitTrackerViewModel()
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Habit Tracker")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                    Text("Today").tag(0)
                    Text("Streaks").tag(1)
                    Text("Stats").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {
                    if selectedTab == 0 {
                        HabitTrackerTodayView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        HabitTrackerStreaksView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        HabitTrackerStatsView(viewModel: viewModel)
                    }

            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) {
            HabitTrackerHabitEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }
}
