import SwiftUI

// MARK: - Parking View

/// Main parking management view.
/// Shows today's status, quick actions to skip/restore dates,
/// and a list of upcoming skip dates.
struct ParkingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ParkingViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: CortexLayout.sectionSpacing) {
                todayStatusSection
                quickActionsSection
                upcomingSkipsSection
            }
            .padding(CortexLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationTitle(L10n.toolkitParking)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            if viewModel.showConfirmation, let message = viewModel.lastActionMessage {
                confirmationBanner(message: message)
            }
        }
    }

    // MARK: - Today's Status

    private var todayStatusSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Today's Parking")

            CortexCard {
                HStack(spacing: 16) {
                    statusIcon
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(statusIconBackgroundColor.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.cortexHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text(statusSubtitle)
                            .font(.cortexCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: viewModel.todayStatus.iconName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(statusIconColor)
    }

    private var statusTitle: String {
        if !viewModel.isTodayWeekday {
            return "Weekend"
        }
        return viewModel.todayStatus.displayText
    }

    private var statusSubtitle: String {
        if !viewModel.isTodayWeekday {
            return "No parking needed on weekends"
        }
        switch viewModel.todayStatus {
        case .active: return "UVA Zone 5556 parking is active"
        case .skipped: return "Parking purchase was skipped today"
        case .notPurchased: return "Parking has not been purchased yet"
        case .unknown: return "Status will update after next sync"
        }
    }

    private var statusIconColor: Color {
        switch viewModel.todayStatus {
        case .active: return .cortexAccentGreen
        case .skipped: return .cortexAccentYellow
        case .notPurchased: return .cortexAccentRed
        case .unknown: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }

    private var statusIconBackgroundColor: Color {
        statusIconColor
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Quick Actions")

            HStack(spacing: CortexLayout.itemSpacing) {
                quickActionButton(
                    title: "Skip Today",
                    icon: "calendar.badge.minus",
                    color: .cortexAccentYellow,
                    disabled: !viewModel.isTodayWeekday
                ) {
                    viewModel.skipToday()
                }

                quickActionButton(
                    title: "Skip Tomorrow",
                    icon: "arrow.right.circle",
                    color: .cortexAccentYellow,
                    disabled: !viewModel.isTomorrowWeekday
                ) {
                    viewModel.skipTomorrow()
                }
            }

            quickActionWideButton(
                title: "Skip Next Week (Mon-Fri)",
                icon: "calendar.badge.exclamationmark",
                color: .cortexAccentRed
            ) {
                viewModel.skipNextWeek()
            }
        }
    }

    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(disabled ? AdaptiveColors.textSecondary(for: colorScheme) : color)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(disabled
                        ? AdaptiveColors.textSecondary(for: colorScheme)
                        : AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .disabled(disabled)
    }

    private func quickActionWideButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .padding(CortexLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
    }

    // MARK: - Upcoming Skips

    private var upcomingSkipsSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Upcoming Skip Dates")

            if viewModel.upcomingSkipDates.isEmpty {
                CortexCard {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.cortexAccentGreen)
                        Text("No upcoming skips")
                            .font(.cortexBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.upcomingSkipDates) { entry in
                        skipDateRow(entry: entry)
                    }
                }
            }
        }
    }

    private func skipDateRow(entry: ParkingSkipEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.cortexAccentYellow)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.relativeDateLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(entry.formattedDate)
                    .font(.cortexCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.restoreDate(entry)
                }
            } label: {
                Text("Restore")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cortexPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.cortexPrimary.opacity(0.12))
                    )
            }
        }
        .padding(CortexLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }

    // MARK: - Confirmation Banner

    private func confirmationBanner(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.cortexAccentGreen)
                    .shadow(color: Color.cortexAccentGreen.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.showConfirmation = false
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ParkingView()
    }
}
