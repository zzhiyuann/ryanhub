import SwiftUI

struct RecipeBoxView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = RecipeBoxViewModel()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "book.closed")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Recipe Box")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

                RecipeBoxRecipeCollectionView(viewModel: viewModel)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) {
            RecipeBoxRecipeEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
        }
    }
}
