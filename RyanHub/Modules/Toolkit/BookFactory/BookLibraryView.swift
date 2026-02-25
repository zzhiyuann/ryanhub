import SwiftUI

/// Grid/list of books in the Book Factory library.
/// Supports search, pull-to-refresh, audio generation triggers, and playback.
struct BookLibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(BookFactoryViewModel.self) private var vm
    @Environment(BookFactoryAPI.self) private var api
    @Environment(AudioPlayerViewModel.self) private var audioPlayer
    @State private var selectedBook: Book?
    @State private var audioModeBook: Book?

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Group {
                if vm.isLoading && vm.books.isEmpty {
                    loadingView
                } else if vm.books.isEmpty {
                    emptyView
                } else {
                    bookList
                }
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.search, prompt: "Search books...")
            .refreshable {
                await vm.loadBooks()
            }
            .navigationDestination(item: $selectedBook) { book in
                BookReaderView(book: book)
                    .environment(api)
                    .environment(audioPlayer)
            }
            .confirmationDialog(
                "Audio Version",
                isPresented: Binding(
                    get: { audioModeBook != nil },
                    set: { if !$0 { audioModeBook = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Full Book") {
                    if let book = audioModeBook {
                        Task { await vm.generateAudio(bookId: book.id, mode: "long") }
                    }
                    audioModeBook = nil
                }
                Button("Summary (~10 min)") {
                    if let book = audioModeBook {
                        Task { await vm.generateAudio(bookId: book.id, mode: "short") }
                    }
                    audioModeBook = nil
                }
                Button("Cancel", role: .cancel) {
                    audioModeBook = nil
                }
            } message: {
                Text("Choose the audio version to generate.")
            }
            .overlay {
                // New books banner
                if let banner = vm.newBooksBanner {
                    VStack {
                        Text(banner)
                            .font(.hubCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.hubPrimary)
                            )
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring, value: vm.newBooksBanner)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading library...")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Books", systemImage: "books.vertical")
        } description: {
            Text("Your library is empty. Generate some books first!")
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing) {
                ForEach(vm.groupedBooks, id: \.date) { group in
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: group.date)
                            .padding(.horizontal, HubLayout.standardPadding)

                        ForEach(group.books) { book in
                            BookCardView(
                                book: book,
                                audioProgress: vm.generatingAudio[book.id],
                                onTap: { selectedBook = book },
                                onPlay: {
                                    Task {
                                        await audioPlayer.startPlaying(bookId: book.id, title: book.title)
                                    }
                                },
                                onGenerate: {
                                    audioModeBook = book
                                }
                            )
                            .padding(.horizontal, HubLayout.standardPadding)
                        }
                    }
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
    }
}

// MARK: - Book Card

struct BookCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let book: Book
    let audioProgress: BookFactoryViewModel.AudioProgress?
    let onTap: () -> Void
    let onPlay: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        Button(action: onTap) {
            HubCard {
                HStack(alignment: .top, spacing: 12) {
                    // Book info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let topic = book.topic {
                            Text(topic)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            Text(BookFormatting.wordCount(book.wordCount))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            if let slot = book.slot {
                                Text(slot)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }

                            if book.hasAudioBool, let dur = book.audioDuration {
                                Label(BookFormatting.shortDuration(dur), systemImage: "headphones")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.hubPrimary)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // Audio action button
                    audioButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var audioButton: some View {
        if book.hasAudioBool {
            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.hubPrimary, in: Circle())
            }
            .buttonStyle(.plain)
        } else if let progress = audioProgress {
            // Generation progress
            VStack(spacing: 4) {
                ProgressView(value: progress.progress)
                    .tint(.hubPrimary)
                    .frame(width: 50)
                Text(BookFormatting.progress(progress.progress))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        } else {
            // Generate button
            Button(action: onGenerate) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let api = BookFactoryAPI(baseURL: "https://example.com")
    let vm = BookFactoryViewModel(api: api)
    let audio = AudioPlayerViewModel(api: api)

    BookLibraryView()
        .environment(api)
        .environment(vm)
        .environment(audio)
}
