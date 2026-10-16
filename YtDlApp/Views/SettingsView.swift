import SwiftUI

struct SettingsView: View {
    @Environment(PreferencesStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(AppState.self) private var appState
    @AppStorage(VLCOpener.settingKey) private var openInVLC = true
    @AppStorage("autoPasteLinks") private var autoPaste = true
    @State private var showFolderPicker = false
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                // MARK: a-Shell
                Section {
                    NavigationLink {
                        SetupGuideView()
                    } label: {
                        Label("Set-up guide", systemImage: "list.number")
                    }
                    Picker("Run downloads via", selection: $store.prefs.runMethod) {
                        ForEach(RunMethod.allCases) { Text($0.label).tag($0) }
                    }
                    if store.prefs.runMethod == .shortcut {
                        LabeledContent("Shortcut name") {
                            TextField("yt-dlp", text: $store.prefs.shortcutName)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    LabeledContent("yt-dlp command") {
                        TextField(DownloadPreferences.defaultYtDlpCommand, text: $store.prefs.ytDlpCommand)
                            .multilineTextAlignment(.trailing)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Return here when finished", isOn: $store.prefs.returnToAppWhenDone)
                    Button {
                        run(DownloadPreferences.updateCommand)
                    } label: {
                        Label("Update yt-dlp", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("a-Shell")
                } footer: {
                    Text(store.prefs.runMethod.footer)
                }

                // MARK: Folders
                Section {
                    LabeledContent("a-Shell bookmark") {
                        TextField("none", text: $store.prefs.folderBookmark)
                            .multilineTextAlignment(.trailing)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if store.prefs.trimmedBookmark.isEmpty {
                        LabeledContent("Save to") {
                            TextField("~/Documents/yt-dl", text: $store.prefs.outputFolder)
                                .multilineTextAlignment(.trailing)
                                .font(.callout.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    LabeledContent("Library folder") {
                        Text(library.folderURL?.lastPathComponent ?? "Not linked")
                            .foregroundStyle(library.folderURL == nil ? Color.red : Color.secondary)
                    }
                    Button(library.folderURL == nil ? "Link folder…" : "Change linked folder…") {
                        showFolderPicker = true
                    }
                    Toggle("Tap a file to open it in VLC", isOn: $openInVLC)
                    Toggle("Auto-fill copied YouTube links", isOn: $autoPaste)
                } header: {
                    Text("Folders")
                } footer: {
                    Text("To save into another app's folder, such as VLC, give a-Shell access with pickFolder and bookmark it (see the set-up guide), then enter the bookmark name here. Otherwise files go to the “Save to” path inside a-Shell. Link the same folder for the Library.")
                }

                // MARK: Video
                Section {
                    Picker("Quality", selection: $store.prefs.videoQuality) {
                        ForEach(VideoQuality.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Container", selection: $store.prefs.videoContainer) {
                        ForEach(VideoContainer.allCases) { Text($0.label).tag($0) }
                    }
                    if store.prefs.videoContainer == .mp4 {
                        Toggle("Prefer iPhone-friendly codecs", isOn: $store.prefs.preferCompatibleCodecs)
                    }
                } header: {
                    Text("Video")
                } footer: {
                    if store.prefs.videoContainer != .mp4 {
                        Text("MKV and WebM files may not play in this app, Photos or Files. Use them if you watch in VLC or Infuse.")
                    } else if store.prefs.preferCompatibleCodecs {
                        Text("Picks H.264 + AAC, which plays everywhere on iOS. YouTube only offers H.264 up to 1080p, so higher qualities fall back to 1080p.")
                    } else {
                        Text("Highest-quality streams are often VP9 or AV1. These may not play on older devices.")
                    }
                }

                Section {
                    Toggle("Download subtitles", isOn: $store.prefs.downloadSubtitles)
                    if store.prefs.downloadSubtitles {
                        Toggle("Include auto-generated", isOn: $store.prefs.autoSubtitles)
                        LabeledContent("Languages") {
                            TextField("en.*", text: $store.prefs.subtitleLanguages)
                                .multilineTextAlignment(.trailing)
                                .font(.callout.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                } header: {
                    Text("Subtitles (video only)")
                } footer: {
                    Text("Embedded into the video. Languages are comma-separated codes such as en,da or en.* for all English variants.")
                }

                // MARK: Audio
                Section("Audio") {
                    Picker("Format", selection: $store.prefs.audioFormat) {
                        ForEach(AudioFormat.allCases) { Text($0.label).tag($0) }
                    }
                    if store.prefs.audioFormat.isLossy {
                        Picker("Quality", selection: $store.prefs.audioQuality) {
                            ForEach(AudioQuality.allCases) { Text($0.label).tag($0) }
                        }
                    }
                }

                // MARK: Files
                Section {
                    Picker("File name", selection: $store.prefs.filenameStyle) {
                        ForEach(FilenameStyle.allCases) { Text($0.label).tag($0) }
                    }
                    if store.prefs.filenameStyle == .custom {
                        TextField("%(title)s.%(ext)s", text: $store.prefs.customTemplate)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Thumbnails & details in subfolders", isOn: $store.prefs.sidecarsInSubfolders)
                    Toggle("Plain ASCII file names", isOn: $store.prefs.restrictFilenames)
                } header: {
                    Text("Files")
                } footer: {
                    Text("Subfolders keep the download folder tidy: thumbnails go in “thumbnails”, video details in “metadata”. Plain ASCII replaces spaces and accents, which is safer for some apps but uglier.")
                }

                // MARK: Thumbnails & metadata
                Section {
                    Toggle("Save thumbnail", isOn: $store.prefs.writeThumbnail)
                    Toggle("Embed thumbnail as cover art", isOn: $store.prefs.embedThumbnail)
                    Toggle("Save video details", isOn: $store.prefs.writeInfoJSON)
                    Toggle("Embed metadata", isOn: $store.prefs.embedMetadata)
                    Group {
                        Toggle("Channel as artist", isOn: $store.prefs.channelAsArtist)
                        Toggle("Channel as album", isOn: $store.prefs.channelAsAlbum)
                    }
                    .disabled(!store.prefs.embedMetadata)
                    Toggle("Embed chapters", isOn: $store.prefs.embedChapters)
                } header: {
                    Text("Thumbnails & metadata")
                } footer: {
                    Text("The saved thumbnail and video details are what the Library uses to show artwork, titles, channels and lengths. Embedded metadata sets the title to the video name and the artist and album artist to the channel, so Music and other players show them properly.")
                }

                // MARK: SponsorBlock
                Section {
                    Toggle("Cut segments with SponsorBlock", isOn: $store.prefs.sponsorBlockRemove)
                    if store.prefs.sponsorBlockRemove {
                        ForEach(SponsorBlockCategory.all) { category in
                            Toggle(category.label, isOn: categoryBinding(category.id))
                        }
                    }
                } header: {
                    Text("SponsorBlock")
                } footer: {
                    Text("Removes community-marked segments from the downloaded file.")
                }

                // MARK: Advanced
                Section {
                    Picker("Playlist links", selection: $store.prefs.playlist) {
                        ForEach(PlaylistHandling.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Skip already-downloaded videos", isOn: $store.prefs.useDownloadArchive)
                    LabeledContent("Speed limit") {
                        TextField("e.g. 5M", text: $store.prefs.rateLimit)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Extra arguments")
                        TextField("--cookies cookies.txt", text: $store.prefs.extraArguments, axis: .vertical)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Extra arguments are added to every download, before the link.")
                }

                Section("Command preview") {
                    Text(CommandBuilder.command(urls: ["<link>"], prefs: store.prefs))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section {
                    Button("Reset download settings", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { library.setFolder(url) }
            }
            .confirmationDialog("Reset all download settings to defaults?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.reset() }
            }
        }
    }

    private func categoryBinding(_ id: String) -> Binding<Bool> {
        Binding {
            store.prefs.sponsorBlockCategories.contains(id)
        } set: { on in
            var cats = store.prefs.sponsorBlockCategories.filter { $0 != id }
            if on { cats.append(id) }
            // Keep a stable order matching the list.
            store.prefs.sponsorBlockCategories = SponsorBlockCategory.all.map(\.id).filter { cats.contains($0) }
        }
    }

    private func run(_ command: String) {
        Task {
            let outcome = await AShellRunner.run(command, prefs: store.prefs)
            appState.report(outcome)
        }
    }
}
