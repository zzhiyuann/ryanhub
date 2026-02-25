import SwiftUI

/// Sidebar showing all chat sessions, grouped by date.
/// Presented as a sheet from the chat view, mimicking ChatGPT/Claude iOS sidebar.
struct ChatSidebarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var sessions: [ChatSession]
    var currentSessionId: String?
    var onSelectSession: (String) -> Void
    var onNewChat: () -> Void
    var onDeleteSession: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveColors.background(for: colorScheme)
                    .ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onNewChat()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Session List

    @ViewBuilder
    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.0) { group, sessionsInGroup in
                Section {
                    ForEach(sessionsInGroup) { session in
                        sessionRow(session)
                            .listRowBackground(
                                session.id == currentSessionId
                                    ? Color.hubPrimary.opacity(0.12)
                                    : AdaptiveColors.surface(for: colorScheme)
                            )
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            onDeleteSession(sessionsInGroup[offset].id)
                        }
                    }
                } header: {
                    Text(group.rawValue)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Session Row

    @ViewBuilder
    private func sessionRow(_ session: ChatSession) -> some View {
        Button {
            onSelectSession(session.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    Spacer()

                    Text(session.lastMessageAt.relativeDateString)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                if !session.lastMessagePreview.isEmpty {
                    Text(session.lastMessagePreview)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))

            Text("No conversations yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Button {
                onNewChat()
                dismiss()
            } label: {
                Label("New Chat", systemImage: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)
            }
        }
    }

    // MARK: - Grouping

    /// Group sessions by date category, maintaining order.
    private var groupedSessions: [(ChatSession.DateGroup, [ChatSession])] {
        let grouped = Dictionary(grouping: sessions) { $0.dateGroup }
        return ChatSession.DateGroup.allCases.compactMap { group in
            guard let sessionsInGroup = grouped[group], !sessionsInGroup.isEmpty else { return nil }
            return (group, sessionsInGroup.sorted { $0.lastMessageAt > $1.lastMessageAt })
        }
    }
}

// MARK: - Date Formatting

private extension Date {
    /// Relative date string for sidebar display.
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date.now

        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  self > sevenDaysAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}
