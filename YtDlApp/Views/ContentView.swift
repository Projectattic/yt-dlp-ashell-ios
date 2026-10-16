import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            DownloadView()
                .tabItem { Label("Download", systemImage: "arrow.down.circle") }
                .tag(AppState.Tab.download)
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack.fill") }
                .tag(AppState.Tab.library)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Tab.settings)
        }
        .onOpenURL(perform: handleURL)
        .onChange(of: scenePhase) { _, phase in
            // Coming back from a-Shell: pick up whatever it downloaded.
            if phase == .active {
                Task { await appState.checkActiveDownload(in: library, finished: false) }
            }
        }
        .overlay(alignment: .top) {
            if let banner = appState.banner {
                BannerView(banner: banner)
                    .onTapGesture { appState.banner = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: appState.banner)
    }

    /// ytdlapp://download?url=…   – prefill a link (e.g. from a share-sheet Shortcut)
    /// ytdlapp://done | error | cancelled – Shortcuts x-callback results
    private func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == "ytdlapp" else { return }
        switch url.host?.lowercased() {
        case "download":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let link = query.first(where: { $0.name == "url" })?.value, !link.isEmpty {
                appState.linkText = link
            }
            appState.selectedTab = .download
        case "finished":
            // Sent by a-Shell after yt-dlp exits (see CommandBuilder).
            appState.selectedTab = .download
            Task { await appState.checkActiveDownload(in: library, finished: true) }
        case "done":
            Task { await appState.checkActiveDownload(in: library, finished: false) }
        case "error":
            let message = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "errorMessage" })?.value
            appState.show(message.map { "Shortcut error: \($0)" }
                          ?? "The Shortcut failed. Check its name in Settings.", isError: true)
        case "cancelled":
            appState.show("The Shortcut was cancelled.")
        default:
            break
        }
    }
}

private struct BannerView: View {
    let banner: Banner

    var body: some View {
        Label(banner.message, systemImage: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(banner.isError ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(banner.isError ? Color.red : Color(.secondarySystemBackground))
            )
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }
}
