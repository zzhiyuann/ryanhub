import SwiftUI

// MARK: - MedicationTracker Today View

struct MedicationTrackerTodayView: View {
    let viewModel: MedicationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var doseLogs: [String: DoseStatus] = [:]
    @State private var doseActionTimes: [String: Date] = [:]
    @State private var pulseAnimation = false

    // MARK: - Computed

    private var activeMedications: [MedicationTrackerEntry] {
        viewModel.entries.filter { $0.isActive }
    }

    private var scheduledDoses: [ScheduledDose] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        return activeMedications.flatMap { med -> [ScheduledDose] in
            guard med.frequency.isScheduled else { return [] }
            return med.frequency.defaultTimeOffsets.enumerated().map { index, offset in
                let scheduledTime = startOfDay.addingTimeInterval(TimeInterval(offset))
                let doseId = "\(med.id)_\(index)"
                let status = doseLogs[doseId] ?? computeStatus(for: scheduledTime)
                return ScheduledDose(
                    id: doseId,
                    medication: med,
                    scheduledTime: scheduledTime,
                    status: status,
                    takenTime: doseActionTimes[doseId]
                )
            }
        }.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    private var groupedDoses: [(TimeSlot, [ScheduledDose])] {
        let grouped = Dictionary(grouping: scheduledDoses) { $0.timeSlot }
        return TimeSlot.allCases.compactMap { slot in
            guard let doses = grouped[slot], !doses.isEmpty else { return nil }
            return (slot, doses)
        }
    }

    private var totalDoses: Int { scheduledDoses.count }

    private var takenDoses: Int {
        scheduledDoses.filter { $0.status == .taken }.count
    }

    private var progress: Double {
        guard totalDoses > 0 else { return 1.0 }
        return Double(takenDoses) / Double(totalDoses)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                headerSection

                if scheduledDoses.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedDoses, id: \.0) { slot, doses in
                        timeSlotSection(slot: slot, doses: doses)
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            loadSavedLogs()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HubCard {
            HStack(spacing: HubLayout.sectionSpacing) {
                ProgressRingView(
                    progress: progress,
                    current: "\(takenDoses)",
                    goal: "of \(totalDoses) doses",
                    color: progress >= 1.0 ? Color.hubAccentGreen : Color.hubPrimary,
                    size: 100,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Today's Medications")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if viewModel.currentStreak > 0 {
                        streakBadge
                    }

                    statusSummary
                }

                Spacer()
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color.hubAccentYellow)
            Text("\(viewModel.currentStreak)-day streak")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.hubAccentYellow.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusSummary: some View {
        let missedCount = scheduledDoses.filter { $0.status == .missed }.count
        let skippedCount = scheduledDoses.filter { $0.status == .skipped }.count

        if missedCount > 0 {
            Label("\(missedCount) missed", systemImage: "xmark.circle.fill")
                .font(.hubCaption)
                .foregroundStyle(Color.hubAccentRed)
        }
        if skippedCount > 0 {
            Label("\(skippedCount) skipped", systemImage: "forward.fill")
                .font(.hubCaption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Time Slot Section

    private func timeSlotSection(slot: TimeSlot, doses: [ScheduledDose]) -> some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            HStack(spacing: 8) {
                Image(systemName: slot.icon)
                    .foregroundStyle(Color.hubPrimary)
                Text(slot.displayName)
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                let slotTaken = doses.filter { $0.status == .taken }.count
                Text("\(slotTaken)/\(doses.count)")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            ForEach(doses) { dose in
                doseCard(dose)
            }
        }
    }

    // MARK: - Dose Card

    private func doseCard(_ dose: ScheduledDose) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                Circle()
                    .fill(dose.medication.colorValue)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dose.medication.name.isEmpty ? "Untitled" : dose.medication.name)
                        .font(.hubBody)
                        .fontWeight(.medium)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .strikethrough(dose.status == .taken, color: AdaptiveColors.textSecondary(for: colorScheme))

                    HStack(spacing: 6) {
                        if !dose.medication.dosage.isEmpty {
                            Text(dose.medication.dosage)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        Image(systemName: dose.medication.form.icon)
                            .font(.caption2)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(dose.formattedScheduledTime)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    statusBadge(dose)
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(
                    dose.isDueNow && !dose.status.isResolved
                        ? Color.hubAccentYellow.opacity(pulseAnimation ? 0.8 : 0.2)
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .opacity(dose.status.isResolved ? 0.75 : 1.0)
        .onTapGesture {
            guard !dose.status.isResolved else { return }
            markAsTaken(dose)
        }
        .onLongPressGesture {
            guard !dose.status.isResolved else { return }
            markAsSkipped(dose)
        }
    }

    // MARK: - Status Badge

    private func statusBadge(_ dose: ScheduledDose) -> some View {
        HStack(spacing: 4) {
            Image(systemName: dose.status.icon)
            if dose.status == .taken, let takenTime = dose.takenTime {
                Text(formatTime(takenTime))
            } else {
                Text(dose.status.displayName)
            }
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(dose.status.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(dose.status.color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text("No medications scheduled")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text("Add medications to see your daily schedule")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(HubLayout.sectionSpacing)
        }
    }

    // MARK: - Helpers

    private func computeStatus(for scheduledTime: Date) -> DoseStatus {
        let now = Date()
        let windowBefore = scheduledTime.addingTimeInterval(-30 * 60)
        let windowAfter = scheduledTime.addingTimeInterval(30 * 60)

        if now < windowBefore {
            return .upcoming
        } else if now <= windowAfter {
            return .due
        } else {
            return .missed
        }
    }

    private func markAsTaken(_ dose: ScheduledDose) {
        withAnimation(.spring(response: 0.3)) {
            doseLogs[dose.id] = .taken
            doseActionTimes[dose.id] = Date()
            persistLogs()
        }
    }

    private func markAsSkipped(_ dose: ScheduledDose) {
        withAnimation(.spring(response: 0.3)) {
            doseLogs[dose.id] = .skipped
            persistLogs()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var todayStorageKey: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "medtracker_doses_\(df.string(from: Date()))"
    }

    private func persistLogs() {
        if let data = try? JSONEncoder().encode(doseLogs) {
            UserDefaults.standard.set(data, forKey: todayStorageKey)
        }
        let timeIntervals = doseActionTimes.mapValues { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(timeIntervals) {
            UserDefaults.standard.set(data, forKey: "\(todayStorageKey)_times")
        }
    }

    private func loadSavedLogs() {
        if let data = UserDefaults.standard.data(forKey: todayStorageKey),
           let logs = try? JSONDecoder().decode([String: DoseStatus].self, from: data) {
            doseLogs = logs
        }
        if let data = UserDefaults.standard.data(forKey: "\(todayStorageKey)_times"),
           let times = try? JSONDecoder().decode([String: Double].self, from: data) {
            doseActionTimes = times.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }
}