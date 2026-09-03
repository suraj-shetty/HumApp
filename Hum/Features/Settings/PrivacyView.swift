import SwiftUI

/// Design screen 41. **Opaque content.**
///
/// Every line here states a fact about this app's actual architecture rather
/// than a generic privacy-screen template — checked against the real
/// pieces: `AppEnvironment.live()`'s MusicKit token is the system's own
/// keychain-held credential, `RecentSearches` (`Features/Search/SearchView.swift`)
/// really is `UserDefaults`-only, and there genuinely is no analytics or
/// crash-reporting dependency anywhere in this target.
struct PrivacyView: View {
    @State private var isShowingClearConfirmation = false
    @State private var didClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Hum has no account and no server. Everything below stays on this iPhone.")
                    .humFont(16, weight: .light)
                    .lineSpacing(4)
                    .foregroundStyle(Palette.textPrimary.opacity(0.72))

                card {
                    privacyRow(
                        icon: "lock.rectangle",
                        title: "MusicKit token",
                        detail: "Held in the keychain, used only to talk to Apple Music. Revoking access deletes it."
                    )
                    Divider().overlay(Palette.hairline).padding(.leading, 52)
                    privacyRow(
                        icon: "clock",
                        title: "Recent searches",
                        detail: "Stored locally, never sent anywhere."
                    )
                    Divider().overlay(Palette.hairline).padding(.leading, 52)
                    privacyRow(
                        icon: HumIcon.warning,
                        title: "No analytics",
                        detail: "No tracking SDKs, no crash uploads without asking, no ads."
                    )
                }

                card {
                    if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                        Link(destination: url) {
                            HStack {
                                Text("Apple's privacy policy")
                                    .humFont(16)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .humFont(13, weight: .semibold)
                                    .foregroundStyle(Palette.textMuted)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                    }
                    Divider().overlay(Palette.hairline)
                    Button {
                        isShowingClearConfirmation = true
                    } label: {
                        Text("Clear local data")
                            .humFont(16)
                            .foregroundStyle(Palette.terracotta)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }

                if didClear {
                    Text("Local data cleared.")
                        .humFont(12.5, weight: .light)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Palette.deepOnyx)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        // Only recent searches are actually stored outside the system's own
        // keychain and MusicKit cache, so that's the only thing this can
        // honestly clear — see the doc comment above.
        .confirmationDialog(
            "Clear local data?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Recent Searches", role: .destructive) {
                RecentSearches.clearAll()
                didClear = true
            }
        } message: {
            Text("This removes your recent searches from this iPhone. Your library and Apple Music access are unaffected.")
        }
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .humFont(18, weight: .regular)
                .foregroundStyle(Palette.honeyAmber)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .humFont(15.5)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .humFont(13, weight: .light)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(16)
    }

    private func card(@ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rows()
        }
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
