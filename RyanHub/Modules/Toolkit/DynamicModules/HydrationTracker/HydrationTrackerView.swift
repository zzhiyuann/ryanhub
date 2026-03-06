import SwiftUI

struct HydrationTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HydrationTrackerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Hydration Tracker")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

                HydrationTrackerTodayView(viewModel: viewModel)
            }
            .padding(.bottom, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
