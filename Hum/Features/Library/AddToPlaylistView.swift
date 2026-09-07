import SwiftUI

/// Design screen 32. **Chrome — sheet.**
///
/// `MusicLibraryService.add(_:to:)` and `.createPlaylist(name:description:)`
/// back this and `NewPlaylistView` below — real `MusicLibrary.shared`
/// writes, the same family as the existing "Add to Library" action
/// (DECISIONS M-04), not a mocked-up flow. This is what the track context
/// menu's "Add to Playlist…" was left out for — see `TrackRow`'s own doc
/// comment, which this closes out.
struct AddToPlaylistView: View {
    let track: HumTrack

    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var playlists: LoadState<[HumCollection]> = .idle
    @State private var isPresentingNewPlaylist = false
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    isPresentingNewPlaylist = true
                } label: {
                    HStack(spacing: 14) {
                        Circle()
                            .strokeBorder(Palette.honeyAmber.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "plus")
                                    .humFont(20, weight: .regular)
                                    .foregroundStyle(Palette.honeyAmber)
                            }
                        Text("New Playlist")
                            .humFont(16.5)
                            .foregroundStyle(Palette.honeyAmber)
                    }
                }
                .disabled(isAdding)
                .listRowBackground(Palette.deepOnyx)

                if let errorMessage {
                    InlineError(message: errorMessage)
                        .listRowBackground(Palette.deepOnyx)
                }

                switch playlists {
                case .idle, .loading:
                    RowSkeleton(count: 3)
                        .listRowBackground(Palette.deepOnyx)
                        .listRowSeparator(.hidden)

                case .loaded(let collections) where collections.isEmpty:
                    EmptyView()

                case .loaded(let collections):
                    ForEach(collections) { playlist in
                        Button {
                            add(to: playlist)
                        } label: {
                            HStack(spacing: 14) {
                                ArtworkView(url: playlist.artworkURL, size: 52, cornerRadius: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.title)
                                        .humFont(16)
                                        .foregroundStyle(Palette.textPrimary)
                                    Text(playlist.metaLine)
                                        .humFont(13)
                                        .foregroundStyle(Palette.textMuted)
                                }
                            }
                        }
                        .disabled(isAdding)
                        .listRowBackground(Palette.deepOnyx)
                    }

                case .failed(let message):
                    InlineError(message: message)
                        .listRowBackground(Palette.deepOnyx)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.deepOnyx)
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Palette.honeyAmber)
                        .disabled(isAdding)
                }
            }
            .task {
                guard case .idle = playlists else { return }
                playlists = .loading
                do {
                    playlists = .loaded(try await environment.library.playlists())
                } catch {
                    playlists = .failed("Couldn't load your playlists.")
                }
            }
            .sheet(isPresented: $isPresentingNewPlaylist) {
                NewPlaylistView { newPlaylist in
                    add(to: newPlaylist)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func add(to playlist: HumCollection) {
        isAdding = true
        errorMessage = nil
        Task {
            do {
                try await environment.library.add(track, to: playlist)
                dismiss()
            } catch {
                isAdding = false
                errorMessage = "Couldn't add to \(playlist.title)."
            }
        }
    }
}

/// Design screen 42. Cover picking is left out — `MusicLibrary.shared`'s
/// playlist-creation API takes a name and description, nothing image-shaped,
/// so there's no real artwork capability behind that control. "Show in
/// Apple Music" is left out for the same reason: every playlist
/// `MusicLibrary.shared.createPlaylist` makes already syncs through the
/// listener's account — there's no private/local option to toggle.
struct NewPlaylistView: View {
    /// Called once the playlist is actually created, with the real
    /// collection MusicKit handed back.
    var onCreated: (HumCollection) -> Void

    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Playlist Name", text: $name)
                    .humFont(17)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .humFont(16)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(16)
                    .frame(minHeight: 88, alignment: .top)
                    .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorMessage {
                    Text(errorMessage)
                        .humFont(13)
                        .foregroundStyle(Palette.terracottaLift)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)
            .background(Palette.deepOnyx)
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Palette.honeyAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") { create() }
                            .tint(Palette.honeyAmber)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let playlist = try await environment.library.createPlaylist(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                onCreated(playlist)
                dismiss()
            } catch {
                isCreating = false
                errorMessage = "Couldn't create the playlist."
            }
        }
    }
}
