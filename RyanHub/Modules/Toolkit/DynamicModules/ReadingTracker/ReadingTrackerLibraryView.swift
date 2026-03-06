import SwiftUI

// MARK: - ReadingTrackerLibraryView

struct ReadingTrackerLibraryView: View {
    let viewModel: ReadingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                searchBar

                if viewModel.filteredEntries.isEmpty && !viewModel.searchText.isEmpty {
                    emptySearchView
                } else {
                    shelfSection(
                        title: "Currently Reading",
                        icon: "book.fill",
                        books: viewModel.filteredCurrentlyReading,
                        color: Color.hubPrimary
                    )

                    shelfSection(
                        title: "Want to Read",
                        icon: "star",
                        books: viewModel.filteredWantToRead,
                        color: Color.hubAccentYellow
                    )

                    shelfSection(
                        title: "Finished",
                        icon: "checkmark.circle.fill",
                        books: viewModel.filteredFinished,
                        color: Color.hubAccentGreen
                    )

                    shelfSection(
                        title: "Abandoned",
                        icon: "xmark.circle",
                        books: viewModel.filteredAbandoned,
                        color: Color.hubAccentRed
                    )
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            TextField("Search books, authors, genres…", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .font(.hubBody)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(12)
        .background(AdaptiveColors.surfaceSecondary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
        .padding(.horizontal, HubLayout.standardPadding)
    }

    // MARK: - Empty Search

    private var emptySearchView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Text("No books found")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Try a different search term")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Shelf Section

    @ViewBuilder
    private func shelfSection(title: String, icon: String, books: [ReadingTrackerEntry], color: Color) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                shelfHeader(title: title, icon: icon, count: books.count, color: color)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: HubLayout.itemSpacing) {
                        ForEach(books) { book in
                            ReadingBookCardView(
                                book: book,
                                viewModel: viewModel,
                                accentColor: color,
                                colorScheme: colorScheme
                            )
                        }
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                }
            }
        }
    }

    // MARK: - Shelf Header

    private func shelfHeader(title: String, icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("\(count)")
                .font(.hubCaption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.85))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, HubLayout.standardPadding)
    }
}

// MARK: - ReadingBookCardView

private struct ReadingBookCardView: View {
    let book: ReadingTrackerEntry
    let viewModel: ReadingTrackerViewModel
    let accentColor: Color
    let colorScheme: ColorScheme

    @State private var showingStatusMenu = false

    var body: some View {
        Button {
            viewModel.selectedBook = book
            viewModel.showingBookDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                bookCover
                bookInfo

                if book.status == .finished && book.rating > 0 {
                    ratingStars
                }

                if book.status == .reading {
                    progressIndicator
                }
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
        .contextMenu {
            statusChangeMenu
        }
    }

    // MARK: - Book Cover

    private var bookCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(genreGradient)
                .frame(width: 140, height: 190)

            VStack(spacing: 6) {
                Image(systemName: book.genre.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))

                Text(book.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 10)

                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private var genreGradient: LinearGradient {
        let baseColors: [Color] = [
            Color.hubPrimary,
            Color.hubAccentGreen,
            Color.hubAccentYellow,
            Color.hubAccentRed,
            .purple,
            .teal,
            .orange,
            .mint,
            .cyan,
            .brown,
            .gray
        ]
        let index = book.genreColorIndex % baseColors.count
        let base = baseColors[index]
        return LinearGradient(
            colors: [base.opacity(0.85), base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Book Info

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.title)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(1)

            Text(book.author)
                .font(.system(size: 12))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .lineLimit(1)
        }
    }

    // MARK: - Rating Stars

    private var ratingStars: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= book.rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(star <= book.rating ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geometry.size.width * book.progressFraction)
                }
            }
            .frame(height: 4)

            Text(book.progressPercentFormatted)
                .font(.system(size: 10))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Status Change Menu

    @ViewBuilder
    private var statusChangeMenu: some View {
        ForEach(ReadingStatus.allCases) { status in
            if status != book.status {
                Button {
                    Task { await viewModel.changeStatus(for: book, to: status) }
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            Task { await viewModel.deleteEntry(book) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}