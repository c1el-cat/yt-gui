import SwiftUI

struct ContentView: View {
    @StateObject private var downloader = YouTubeDownloader()
    @State private var videoURL: String = ""
    @State private var searchQuery: String = ""
    @State private var isLogExpanded: Bool = false
    
    private var isSearchDisabled: Bool {
        searchQuery.isEmpty || downloader.isDownloading || downloader.isAnalyzing || downloader.isSearching
    }
    
    private var isAnalyzeDisabled: Bool {
        videoURL.isEmpty || downloader.isDownloading || downloader.isAnalyzing || downloader.isSearching
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YouTubeから検索")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("キーワード検索", text: $searchQuery)
                                .textFieldStyle(.roundedBorder)
                                .disabled(downloader.isDownloading || downloader.isAnalyzing || downloader.isSearching)
                                .onSubmit {
                                    guard !isSearchDisabled else { return }
                                    downloader.searchVideos(query: searchQuery)
                                }
                            
                            Button(action: {
                                downloader.searchVideos(query: searchQuery)
                            }) {
                                if downloader.isSearching {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("検索")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSearchDisabled)
                        }
                    }
                    
                    if !downloader.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("検索結果")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 0) {
                                ForEach(downloader.searchResults) { item in
                                    HStack(spacing: 12) {
                                        ZStack(alignment: .bottomTrailing) {
                                            if let url = URL(string: item.thumbnail) {
                                                ThumbnailImageView(imageURL: url)
                                                    .frame(width: 80, height: 45)
                                            } else {
                                                ZStack {
                                                    Color(.windowBackgroundColor).opacity(0.4)
                                                    Image(systemName: "video.slash")
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(width: 80, height: 45)
                                                .cornerRadius(6)
                                            }
                                            
                                            if !item.duration.isEmpty {
                                                Text(item.duration)
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.black.opacity(0.7))
                                                    .cornerRadius(4)
                                                    .padding([.bottom, .trailing], 4)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.body)
                                                .lineLimit(1)
                                                .foregroundColor(.primary)
                                            
                                            HStack(spacing: 6) {
                                                Button(action: {
                                                    videoURL = item.url
                                                    downloader.analyzeAndSetupDownload(url: item.url, isAudioOnly: true)
                                                }) {
                                                    Label("音声のみ", systemImage: "music.note")
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                
                                                Button(action: {
                                                    videoURL = item.url
                                                    downloader.analyzeAndSetupDownload(url: item.url, isAudioOnly: false)
                                                }) {
                                                    Label("動画", systemImage: "video")
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 8)
                                    
                                    if item.id != downloader.searchResults.last?.id {
                                        Divider()
                                            .padding(.leading, 100)
                                    }
                                }
                            }
                            .background(Color(.controlBackgroundColor).opacity(0.25))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separatorColor), lineWidth: 0.5)
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("動画のURLを入力")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("https://www.youtube.com/watch?v=...", text: $videoURL)
                                .textFieldStyle(.roundedBorder)
                                .disabled(downloader.isDownloading || downloader.isAnalyzing || downloader.isSearching)
                                .onSubmit {
                                    guard !isAnalyzeDisabled else { return }
                                    downloader.analyzeVideo(url: videoURL)
                                }
                            
                            Button(action: {
                                downloader.analyzeVideo(url: videoURL)
                            }) {
                                if downloader.isAnalyzing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("解析")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isAnalyzeDisabled)
                        }
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            
            Divider()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation(.layoutAnimation) {
                            isLogExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .rotationEffect(.degrees(isLogExpanded ? 90 : 0))
                            Text("プロセスログ")
                                .font(.callout)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    if downloader.isDownloading {
                        ProgressView().controlSize(.small)
                            .scaleEffect(0.7)
                    }
                    
                    Spacer()
                    
                    if isLogExpanded {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(downloader.outputLog, forType: .string)
                        }) {
                            Label("ログをコピー", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .disabled(downloader.outputLog.isEmpty)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.windowBackgroundColor).opacity(0.15))
                
                if isLogExpanded {
                    Divider()
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(downloader.outputLog.isEmpty ? "ログはありません。" : downloader.outputLog)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .id("LogText")
                        }
                        .frame(height: 120)
                        .background(Color.black.opacity(0.08))
                        .onChange(of: downloader.outputLog) {
                            proxy.scrollTo("LogText", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(.ultraThinMaterial)
        .onAppear {
            downloader.checkAllDependencies()
        }
        .sheet(isPresented: $downloader.isOptionsWindowPresented) {
            DownloadOptionsView(videoURL: $videoURL, downloader: downloader)
        }
        .sheet(isPresented: $downloader.showDependencyAlertSheet) {
            DependencyAlertView(downloader: downloader)
        }
    }
}

struct DownloadOptionsView: View {
    @Binding var videoURL: String
    @ObservedObject var downloader: YouTubeDownloader
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        let formatBinding = Binding<VideoFormat?>(
            get: { downloader.selectedFormat },
            set: { newFormat in
                downloader.selectedFormat = newFormat
                if let format = newFormat {
                    downloader.selectedContainer = format.isAudioOnly ? "mp3" : "mp4"
                }
            }
        )
        
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("ダウンロードオプション")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if downloader.videoTitle == "解析中..." || downloader.videoTitle.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("動画の詳細情報を解析しています...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            if !downloader.thumbnailURL.isEmpty, let url = URL(string: downloader.thumbnailURL) {
                                ThumbnailImageView(imageURL: url)
                                    .frame(width: 160, height: 90)
                            } else {
                                ZStack {
                                    Color(.windowBackgroundColor).opacity(0.3)
                                    Image(systemName: "video.slash")
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 160, height: 90)
                                .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(downloader.videoTitle)
                                    .font(.headline)
                                    .lineLimit(3)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    if !downloader.videoDuration.isEmpty {
                                        Label(downloader.videoDuration, systemImage: "clock")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let format = downloader.selectedFormat {
                                        Text(format.isAudioOnly ? "音声ファイルとして保存" : "動画ファイルとして保存")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                                GridRow {
                                    Text("タイトル:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .gridCellAnchor(.trailing)
                                    
                                    TextField("", text: $downloader.editableTitle)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(downloader.isDownloading)
                                }
                                
                                GridRow {
                                    Text("アーティスト:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .gridCellAnchor(.trailing)
                                    
                                    TextField("", text: $downloader.editableAuthor)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(downloader.isDownloading)
                                }
                                
                                GridRow {
                                    Spacer()
                                    
                                    Toggle("サムネイルも一緒に保存する", isOn: $downloader.shouldDownloadThumbnail)
                                        .toggleStyle(.checkbox)
                                        .disabled(downloader.isDownloading)
                                        .padding(.vertical, 2)
                                }
                                
                                GridRow {
                                    Text("拡張子:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .gridCellAnchor(.trailing)
                                    
                                    Picker("", selection: $downloader.selectedContainer) {
                                        if let currentFormat = downloader.selectedFormat, currentFormat.isAudioOnly {
                                            Text("MP3").tag("mp3")
                                            Text("M4A").tag("m4a")
                                        } else {
                                            Text("MP4").tag("mp4")
                                            Text("MKV").tag("mkv")
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .disabled(downloader.isDownloading)
                                }
                                
                                if !downloader.availableFormats.isEmpty {
                                    GridRow {
                                        Text("品質:")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .gridCellAnchor(.trailing)
                                        
                                        Picker("", selection: formatBinding) {
                                            ForEach(downloader.availableFormats, id: \.self) { format in
                                                Text(format.resolution).tag(format as VideoFormat?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .disabled(downloader.isDownloading)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.controlBackgroundColor).opacity(0.4))
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        
                        if downloader.downloadStatus == "downloading" {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("ダウンロード中...")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int(downloader.downloadProgress * 100))%")
                                        .font(.body.monospacedDigit())
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                }
                                
                                ProgressView(value: downloader.downloadProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                
                                HStack {
                                    if !downloader.downloadSpeed.isEmpty {
                                        Label(downloader.downloadSpeed, systemImage: "arrow.down.circle")
                                    }
                                    Spacer()
                                    if !downloader.downloadETA.isEmpty {
                                        Label("残り時間: \(downloader.downloadETA)", systemImage: "clock")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(.controlBackgroundColor).opacity(0.4))
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        } else if downloader.downloadStatus == "success" {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                    Text("ダウンロード完了")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                
                                if let folderURL = downloader.lastDestinationFolderURL {
                                    Button(action: {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
                                    }) {
                                        HStack(spacing: 4) {
                                            Text("保存先フォルダーを開く")
                                                .underline()
                                            Image(systemName: "arrow.up.forward.app")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.accentColor)
                                        .font(.body)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 16)
                            .background(Color(.controlBackgroundColor).opacity(0.4))
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        } else if downloader.downloadStatus == "error" {
                            HStack {
                                Spacer()
                                Label("エラーが発生しました", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.controlBackgroundColor).opacity(0.4))
                            .background(.thinMaterial)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            
            HStack {
                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(downloader.isDownloading)
                
                Spacer()
                
                if downloader.isDownloading {
                    Button(role: .destructive, action: { downloader.stopDownload() }) {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        downloader.downloadVideoWithSavePanel(url: videoURL)
                    }) {
                        Label("ダウンロード", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(downloader.videoTitle == "解析中..." || downloader.videoTitle.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.thinMaterial)
        }
        .frame(width: 580, height: 620)
        .background(
            ZStack {
                if !downloader.thumbnailURL.isEmpty, let url = URL(string: downloader.thumbnailURL) {
                    BlurredBackgroundImageView(imageURL: url)
                }
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }
}

struct ThumbnailImageView: View {
    let imageURL: URL
    @State private var loadedImage: NSImage? = nil
    @State private var isFailed = false
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isFailed {
                ZStack {
                    Color.black.opacity(0.15)
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        var request = URLRequest(url: imageURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                }
            } else {
                DispatchQueue.main.async {
                    self.isFailed = true
                }
            }
        }.resume()
    }
}

struct BlurredBackgroundImageView: View {
    let imageURL: URL
    @State private var loadedImage: NSImage? = nil
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 30, opaque: true)
                        .opacity(0.6)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        var request = URLRequest(url: imageURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                }
            }
        }.resume()
    }
}

struct DependencyAlertView: View {
    @ObservedObject var downloader: YouTubeDownloader
    @Environment(\.dismiss) var dismiss
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("依存ツールが不足しています")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("このアプリを実行するには、以下のコマンドラインツールが必要です。ターミナルでHomebrewを使用してインストールしてください。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("未検出のツール:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    ForEach(downloader.missingDependencies, id: \.self) { dep in
                        Text(dep)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, 60)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("実行するコマンド:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(downloader.installCommand)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(downloader.installCommand, forType: .string)
                    }) {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            Divider()
            
            HStack {
                Button("後で") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(downloader.installCommand, forType: .string)
                    
                    withAnimation(.layoutAnimation) {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.layoutAnimation) {
                            isCopied = false
                        }
                    }
                    
                    if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                        NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration())
                    }
                }) {
                    if isCopied {
                        Label("コピーしました！", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("コピーしてターミナルを開く", systemImage: "terminal")
                    }
                }
                .buttonStyle(.bordered)
                
                Button("再チェック") {
                    downloader.checkAllDependencies()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 390)
    }
}

extension Animation {
    static var layoutAnimation: Animation {
        .interactiveSpring(response: 0.25, dampingFraction: 0.75, blendDuration: 0)
    }
}
