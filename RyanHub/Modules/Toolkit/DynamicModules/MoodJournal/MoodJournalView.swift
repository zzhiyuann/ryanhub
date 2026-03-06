import SwiftUI

struct MoodJournalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = MoodJournalViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Mood Journal")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                    Text("Check In").tag(0)
                    Text("Calendar").tag(1)
                    Text("Trends").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {
                    if selectedTab == 0 {
                        MoodJournalMoodJournalCheckInView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        MoodJournalMoodJournalCalendarView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        MoodJournalMoodJournalTrendsView(viewModel: viewModel)
                    }

            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
