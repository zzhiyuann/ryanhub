import SwiftUI

struct MoodJournalCheckInSheet: View {
    let viewModel: MoodJournalViewModel
    var onSave: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Double = 5
    @State private var selectedEmotion: Emotion = .neutral
    @State private var energyLevel: Int = 5
    @State private var notes: String = ""
    @State private var isNotesExpanded = false

    private var moodFace: String {
        let r = Int(rating)
        switch r {
        case 1...2: return "😣"
        case 3...4: return "😕"
        case 5...6: return "😐"
        case 7...8: return "😊"
        case 9...10: return "😄"
        default: return "😐"
        }
    }

    private var moodLabel: String {
        let r = Int(rating)
        switch r {
        case 1...2: return "Struggling"
        case 3...4: return "Low"
        case 5...6: return "Okay"
        case 7...8: return "Good"
        case 9...10: return "Great"
        default: return "Okay"
        }
    }

    private var moodColor: Color {
        let r = Int(rating)
        switch r {
        case 1...3: return Color.hubAccentRed
        case 4...5: return Color.hubAccentYellow
        case 6...7: return Color.hubPrimary
        case 8...10: return Color.hubAccentGreen
        default: return Color.hubPrimary
        }
    }

    private var batteryIcon: String {
        switch energyLevel {
        case 1...2: return "battery.0percent"
        case 3...4: return "battery.25percent"
        case 5...6: return "battery.50percent"
        case 7...8: return "battery.75percent"
        case 9...10: return "battery.100percent"
        default: return "battery.50percent"
        }
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Mood Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MoodJournalEntry(
                    rating: Int(rating),
                    emotion: selectedEmotion,
                    energyLevel: energyLevel,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                Task { await viewModel.addEntry(entry) }
                onSave?()
                dismiss()
            }
        ) {
            // MARK: - Mood Face

            EntryFormSection(title: "How are you feeling?") {
                VStack(spacing: HubLayout.itemSpacing) {
                    Text(moodFace)
                        .font(.system(size: 80))
                        .animation(.easeInOut(duration: 0.3), value: Int(rating))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text(moodLabel)
                        .font(.hubHeading)
                        .foregroundStyle(moodColor)
                        .animation(.easeInOut(duration: 0.2), value: Int(rating))

                    HStack {
                        Text("1")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Slider(value: $rating, in: 1...10, step: 1)
                            .tint(moodColor)
                        Text("10")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text("\(Int(rating))/10")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            // MARK: - Emotion Tags

            EntryFormSection(title: "Emotion") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Emotion.allCases) { emotion in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedEmotion = emotion
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: emotion.icon)
                                        .font(.system(size: 12))
                                    Text(emotion.displayName)
                                        .font(.hubCaption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedEmotion == emotion
                                        ? moodColor.opacity(0.2)
                                        : AdaptiveColors.surfaceSecondary(for: colorScheme).opacity(0.5)
                                )
                                .foregroundStyle(
                                    selectedEmotion == emotion
                                        ? moodColor
                                        : AdaptiveColors.textSecondary(for: colorScheme)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedEmotion == emotion ? moodColor : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // MARK: - Energy Level

            EntryFormSection(title: "Energy Level") {
                HStack(spacing: HubLayout.itemSpacing) {
                    Image(systemName: batteryIcon)
                        .font(.title2)
                        .foregroundStyle(energyLevel <= 3 ? Color.hubAccentRed : energyLevel <= 6 ? Color.hubAccentYellow : Color.hubAccentGreen)
                        .animation(.easeInOut(duration: 0.2), value: energyLevel)

                    Stepper(value: $energyLevel, in: 1...10) {
                        Text("\(energyLevel)/10")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
            }

            // MARK: - Reflection Notes

            EntryFormSection(title: "Reflection") {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isNotesExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundStyle(Color.hubPrimary)
                            Text(isNotesExpanded ? "Hide notes" : "Add notes...")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                            Image(systemName: isNotesExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                    .buttonStyle(.plain)

                    if isNotesExpanded {
                        TextEditor(text: $notes)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(8)
                            .background(AdaptiveColors.surfaceSecondary(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
}