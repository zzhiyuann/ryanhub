import SwiftUI

struct MoodJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputMoodlevel: Double = 5
    @State private var selectedEmotion: EmotionType = .joyful
    @State private var selectedSecondaryemotion: EmotionType = .joyful
    @State private var inputEnergylevel: Double = 5
    @State private var inputAnxietylevel: Double = 5
    @State private var inputActivities: Set<ActivityTag> = []
    @State private var selectedSocialcontext: SocialContext = .alone
    @State private var inputSleepquality: Double = 5
    @State private var selectedWeather: WeatherType = .sunny
    @State private var inputReflection: String = ""
    @State private var inputGratitude: String = ""
    @State private var inputLogtime: Date = Date()

    var body: some View {
        QuickEntrySheet(
            title: "Add Mood Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MoodJournalEntry(moodLevel: Int(inputMoodlevel), emotion: selectedEmotion, secondaryEmotion: selectedSecondaryemotion, energyLevel: Int(inputEnergylevel), anxietyLevel: Int(inputAnxietylevel), activities: Array(inputActivities), socialContext: selectedSocialcontext, sleepQuality: Int(inputSleepquality), weather: selectedWeather, reflection: inputReflection, gratitude: inputGratitude, logTime: inputLogtime)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Mood Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputMoodlevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputMoodlevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Primary Emotion") {
                    Picker("Primary Emotion", selection: $selectedEmotion) {
                        ForEach(EmotionType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Secondary Emotion") {
                    Picker("Secondary Emotion", selection: $selectedSecondaryemotion) {
                        ForEach(EmotionType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Energy Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputEnergylevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputEnergylevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Anxiety Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputAnxietylevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputAnxietylevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Activities") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                        ForEach(ActivityTag.allCases) { tag in
                            Button {
                                if inputActivities.contains(tag) {
                                    inputActivities.remove(tag)
                                } else {
                                    inputActivities.insert(tag)
                                }
                            } label: {
                                Label(tag.displayName, systemImage: tag.icon)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(inputActivities.contains(tag) ? Color.hubPrimary.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(inputActivities.contains(tag) ? Color.hubPrimary : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .foregroundStyle(inputActivities.contains(tag) ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                }

                EntryFormSection(title: "Social Context") {
                    Picker("Social Context", selection: $selectedSocialcontext) {
                        ForEach(SocialContext.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Sleep Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputSleepquality))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputSleepquality, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Weather") {
                    Picker("Weather", selection: $selectedWeather) {
                        ForEach(WeatherType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Reflection") {
                    HubTextField(placeholder: "Reflection", text: $inputReflection)
                }

                EntryFormSection(title: "Gratitude Note") {
                    HubTextField(placeholder: "Gratitude Note", text: $inputGratitude)
                }

                EntryFormSection(title: "Time of Check-in") {
                    DatePicker("Time of Check-in", selection: $inputLogtime, displayedComponents: .hourAndMinute)
                }
        }
    }
}
