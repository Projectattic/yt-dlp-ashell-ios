import SwiftUI

struct DownloadView: View {
    @Environment(AppState.self) private var appState
    @Environment(PreferencesStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoPasteLinks") private var autoPaste = true
    @State private var lastPasteboardChange = -1
    @State private var copied = false
    @FocusState private var linkFocused: Bool

    private var links: [String] { CommandBuilder.links(from: appState.linkText) }

    private var command: String {
        CommandBuilder.command(urls: links.isEmpty ? ["<link>"] : links, prefs: store.prefs)
    }

    var body: some View {
        @Bindable var appState = appState
        @Bindable var store = store

        NavigationStack {
            Form {
                if let download = appState.activeDownload {
                    Section {
                        DownloadStatusView(download: download) {
                            appState.activeDownload = nil
                            if download.state == .finished { appState.linkText = "" }
                        } showLibrary: {
                            appState.activeDownload = nil
                            appState.linkText = ""
                            appState.selectedTab = .library
                        }
                    }
                }

                Section {
                    TextField("Paste a YouTube link", text: $appState.linkText, axis: .vertical)
                        .lineLimit(1...5)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($linkFocused)
                    HStack {
                        Button {
                            if let text = UIPasteboard.general.string {
                                appState.linkText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        Spacer()
                        if !appState.linkText.isEmpty {
                            Button("Clear", role: .destructive) { appState.linkText = "" }
                                .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Link")
                } footer: {
                    Text(links.count > 1 ? "\(links.count) links" : "Videos, Shorts and playlists all work.")
                }

                Section {
                    Picker("Download", selection: $store.prefs.mode) {
                        ForEach(DownloadMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    switch store.prefs.mode {
                    case .video:
                        Picker("Quality", selection: $store.prefs.videoQuality) {
                            ForEach(VideoQuality.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Container", selection: $store.prefs.videoContainer) {
                            ForEach(VideoContainer.allCases) { Text($0.label).tag($0) }
                        }
                    case .audio:
                        Picker("Format", selection: $store.prefs.audioFormat) {
                            ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
                        }
                        if store.prefs.audioFormat.isLossy {
                            Picker("Quality", selection: $store.prefs.audioQuality) {
                                ForEach(AudioQuality.allCases) { Text($0.label).tag($0) }
                            }
                        }
                    }

                    Button {
                        appState.selectedTab = .settings
                    } label: {
                        LabeledContent("Extras") {
                            Text(store.prefs.extrasSummary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Format")
                }

                Section {
                    Button {
                        linkFocused = false
                        Task {
                            let outcome = await AShellRunner.run(command, prefs: store.prefs)
                            appState.report(outcome)
                            if case .failed = outcome { return }
                            appState.startTracking(links: links)
                        }
                    } label: {
                        Label("Download in a-Shell", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(links.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Text(command)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = command
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy command", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                } header: {
                    Text("Command")
                } footer: {
                    Text("Files are saved to \(store.prefs.destinationDescription).")
                }
            }
            .navigationTitle("Download")
            .onAppear(perform: autoFillFromClipboard)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { autoFillFromClipboard() }
            }
        }
    }

    /// Fills in a YouTube link from the clipboard when the app comes to the front.
    /// Only reads the clipboard when it has changed, so iOS asks at most once per new copy
    /// (and never, once "Paste from Other Apps" is set to Allow).
    private func autoFillFromClipboard() {
        guard autoPaste else { return }
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChange else { return }
        lastPasteboardChange = pasteboard.changeCount
        guard pasteboard.hasURLs || pasteboard.hasStrings,
              let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let lower = text.lowercased()
        let isYouTube = lower.contains("youtube.com/") || lower.contains("youtu.be/")
        guard isYouTube, !text.contains("\n"), text != appState.linkText else { return }
        appState.linkText = text
    }
}

private struct DownloadStatusView: View {
    let download: ActiveDownload
    let dismiss: () -> Void
    let showLibrary: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        switch download.state {
        case .running:
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloading in a-Shell…").font(.headline)
                    Text("Keep a-Shell open until it finishes. It switches back here when done.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hide", action: dismiss).buttonStyle(.borderless).font(.caption)
            }

        case .finished:
            VStack(alignment: .leading, spacing: 10) {
                Label(download.results.count == 1 ? "Downloaded" : "Downloaded \(download.results.count) files",
                      systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                ForEach(download.results.prefix(3)) { item in
                    HStack(spacing: 10) {
                        ThumbnailView(url: item.thumbnailURL, kind: item.kind, maxPixelSize: 240)
                            .frame(width: 80, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                            if let channel = item.channel {
                                Text(channel).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                HStack {
                    if let first = download.results.first {
                        Button {
                            Task {
                                if !(await VLCOpener.open(first.url)) {
                                    appState.show("Couldn't open VLC. Is it installed?", isError: true)
                                }
                            }
                        } label: {
                            Label("Play in VLC", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Library", action: showLibrary).buttonStyle(.bordered)
                    Spacer()
                    Button("Done", action: dismiss).buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)

        case .failed:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No new file arrived").font(.headline)
                    Text("yt-dlp finished without saving a file. Check a-Shell for the error, or try Settings › Update yt-dlp.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Dismiss", action: dismiss).buttonStyle(.borderless).font(.caption)
            }
        }
    }
}
