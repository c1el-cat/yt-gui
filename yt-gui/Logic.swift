import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

struct VideoFormat: Identifiable, Hashable {
    let id: String
    let ext: String
    let resolution: String
    let isAudioOnly: Bool
    let filesize: Int64?
    let sortKey: Int
}

struct SearchResultItem: Identifiable {
    let id = UUID()
    let videoId: String
    let title: String
    let thumbnail: String
    let duration: String
    let url: String
}

class YouTubeDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var isAnalyzing = false
    @Published var isSearching = false
    @Published var outputLog = ""
    
    @Published var isOptionsWindowPresented = false
    
    @Published var missingDependencies: [String] = []
    @Published var showDependencyAlertSheet = false
    
    @Published var videoTitle: String = ""
    @Published var thumbnailURL: String = ""
    @Published var videoDuration: String = ""
    @Published var availableFormats: [VideoFormat] = []
    @Published var selectedFormat: VideoFormat?
    
    @Published var searchResults: [SearchResultItem] = []
    
    @Published var editableTitle: String = ""
    @Published var editableAuthor: String = ""
    @Published var selectedContainer: String = "mp4"
    
    @Published var shouldDownloadThumbnail: Bool = true
    
    @Published var downloadProgress: Double = 0.0
    @Published var downloadSpeed: String = ""
    @Published var downloadETA: String = ""
    @Published var downloadStatus: String = ""
    
    @Published var lastDestinationFolderURL: URL? = nil
    
    private var process: Process?
    private var formatCancellable: AnyCancellable?

    private func formatDuration(seconds: Double) -> String {
        guard seconds > 0 else { return "" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func isCommandInstalled(_ command: String) -> Bool {
        let fileManager = FileManager.default
        let armPath = "/opt/homebrew/bin/\(command)"
        let intelPath = "/usr/local/bin/\(command)"
        
        if fileManager.fileExists(atPath: armPath) || fileManager.fileExists(atPath: intelPath) {
            return true
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        process.environment = env
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func checkAllDependencies() {
        var missing: [String] = []
        
        if !isCommandInstalled("yt-dlp") { missing.append("yt-dlp") }
        if !isCommandInstalled("deno") { missing.append("deno") }
        if !isCommandInstalled("ffmpeg") { missing.append("ffmpeg") }
        
        DispatchQueue.main.async {
            self.missingDependencies = missing
            if !missing.isEmpty {
                self.showDependencyAlertSheet = true
                self.outputLog += "[警告] 以下の依存関係が見つかりません: \(missing.joined(separator: ", "))\n"
            } else {
                self.showDependencyAlertSheet = false
                self.outputLog += "[情報] すべての依存関係が正常に検出されました。\n"
            }
        }
    }
    
    var installCommand: String {
        guard !missingDependencies.isEmpty else { return "" }
        let packages = missingDependencies.joined(separator: " ")
        return "brew install \(packages)"
    }
    
    private func getYTDlpPath() -> String {
        let fileManager = FileManager.default
        let armPath = "/opt/homebrew/bin/yt-dlp"
        let intelPath = "/usr/local/bin/yt-dlp"
        
        if fileManager.fileExists(atPath: armPath) { return armPath }
        else if fileManager.fileExists(atPath: intelPath) { return intelPath }
        return "yt-dlp"
    }

    func searchVideos(query: String) {
        guard !query.isEmpty else { return }
        
        checkAllDependencies()
        if !missingDependencies.isEmpty { return }
        
        isSearching = true
        searchResults = []
        outputLog += "[検索開始] キーワード: \(query)\n"
        
        let ytdlpPath = getYTDlpPath()
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async { self.isSearching = false }
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.arguments = ["ytsearch5:\(query)", "--dump-json", "--flat-playlist", "--force-ipv4", "--sleep-requests", "1"]
            
            var env = ProcessInfo.processInfo.environment
            let currentPath = env["PATH"] ?? ""
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
            process.environment = env
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            var outputData = Data()
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outputData.append(data) }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                outputPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        self.outputLog += "[エラー] 検索プロセスが終了コード \(process.terminationStatus) で失敗しました。\n"
                    }
                    return
                }
                
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                let lines = outputString.components(separatedBy: .newlines)
                
                var items: [SearchResultItem] = []
                for line in lines {
                    guard let lineData = line.data(using: .utf8), !lineData.isEmpty else { continue }
                    if let json = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any] {
                        let id = json["id"] as? String ?? ""
                        let title = json["title"] as? String ?? "不明なタイトル"
                        let url = json["url"] as? String ?? "https://www.youtube.com/watch?v=\(id)"
                        let thumbnail = "https://img.youtube.com/vi/\(id)/mqdefault.jpg"
                        
                        let rawDuration = json["duration"] as? Double ?? 0.0
                        let durationFormatted = self.formatDuration(seconds: rawDuration)
                        
                        if !id.isEmpty {
                            items.append(SearchResultItem(videoId: id, title: title, thumbnail: thumbnail, duration: durationFormatted, url: url))
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.searchResults = items
                    self.outputLog += "[完了] 検索結果を \(items.count) 件取得しました。\n"
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.outputLog += "[エラー] 検索に失敗しました: \(error.localizedDescription)\n"
                }
            }
        }
    }

    func analyzeAndSetupDownload(url: String, isAudioOnly: Bool) {
        analyzeVideo(url: url)
        
        formatCancellable?.cancel()
        formatCancellable = $availableFormats
            .dropFirst()
            .sink { [weak self] formats in
                guard let self = self, !formats.isEmpty else { return }
                
                if isAudioOnly {
                    if let audioFormat = formats.first(where: { $0.isAudioOnly }) {
                        self.selectedFormat = audioFormat
                        self.selectedContainer = "mp3"
                    } else {
                        self.selectedFormat = formats.first
                        self.selectedContainer = "mp3"
                    }
                } else {
                    if let videoFormat = formats.first(where: { !$0.isAudioOnly }) {
                        self.selectedFormat = videoFormat
                        self.selectedContainer = "mp4"
                    } else {
                        self.selectedFormat = formats.first
                        self.selectedContainer = "mp4"
                    }
                }
                self.formatCancellable?.cancel()
            }
    }

    func analyzeVideo(url: String) {
        guard !url.isEmpty else { return }
        
        checkAllDependencies()
        if !missingDependencies.isEmpty { return }
        
        isAnalyzing = true
        isOptionsWindowPresented = true
        
        videoTitle = "解析中..."
        editableTitle = ""
        editableAuthor = ""
        thumbnailURL = ""
        videoDuration = ""
        availableFormats = []
        selectedFormat = nil
        outputLog += "[解析開始] \(url)\n"
        downloadStatus = ""
        
        let ytdlpPath = getYTDlpPath()
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    if self.videoTitle == "解析中..." { self.videoTitle = "" }
                    self.isAnalyzing = false
                }
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.arguments = ["--dump-json", url, "--force-ipv4"]
            
            var env = ProcessInfo.processInfo.environment
            let currentPath = env["PATH"] ?? ""
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
            process.environment = env
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var outputData = Data()
            var errorData = Data()
            
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outputData.append(data) }
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { errorData.append(data) }
            }
            
            do {
                try process.run()
                
                process.waitUntilExit()
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                let remainingOut = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingOut.isEmpty { outputData.append(remainingOut) }
                let remainingErr = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingErr.isEmpty { errorData.append(remainingErr) }
                
                if process.terminationStatus != 0 {
                    let errorString = String(data: errorData, encoding: .utf8) ?? "未知のエラー"
                    DispatchQueue.main.async {
                        self.outputLog += "[エラー] 解析に失敗しました:\n\(errorString)\n"
                    }
                    return
                }
                
                guard let json = try JSONSerialization.jsonObject(with: outputData, options: []) as? [String: Any] else {
                    throw NSError(domain: "YTDL", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSONのパースに失敗しました"])
                }
                
                let title = json["title"] as? String ?? "不明なタイトル"
                let author = json["uploader"] as? String ?? json["artist"] as? String ?? "不明なアーティスト"
                let thumbnail = json["thumbnail"] as? String ?? ""
                
                let rawDuration = json["duration"] as? Double ?? 0.0
                let durationFormatted = self.formatDuration(seconds: rawDuration)
                
                var formatsList: [VideoFormat] = []
                
                if let formats = json["formats"] as? [[String: Any]] {
                    for f in formats {
                        guard let formatId = f["format_id"] as? String,
                              let ext = f["ext"] as? String else { continue }
                        
                        let formatNote = f["format_note"] as? String ?? ""
                        if formatId.contains("storyboard") || formatNote.contains("storyboard") { continue }
                        
                        let acodec = f["acodec"] as? String ?? "none"
                        let vcodec = f["vcodec"] as? String ?? "none"
                        let filesize = f["filesize"] as? Int64 ?? f["filesize_approx"] as? Int64
                        
                        let isAudio = (vcodec == "none" || vcodec.isEmpty) && acodec != "none"
                        var resolutionLabel = ""
                        var sortKey = 0
                        
                        if isAudio {
                            let abr = f["abr"] as? Double ?? 0.0
                            resolutionLabel = "音声のみ (\(Int(abr))kbps)"
                            sortKey = Int(abr)
                        } else {
                            let height = f["height"] as? Int ?? 0
                            let fps = f["fps"] as? Double ?? 0.0
                            let label = f["format_note"] as? String ?? "\(height)p"
                            
                            resolutionLabel = "\(label) (\(Int(fps))fps)"
                            sortKey = height * 10 + Int(fps)
                        }
                        
                        if sortKey > 0 {
                            let item = VideoFormat(
                                id: formatId,
                                ext: ext,
                                resolution: resolutionLabel,
                                isAudioOnly: isAudio,
                                filesize: filesize,
                                sortKey: sortKey
                            )
                            formatsList.append(item)
                        }
                    }
                }
                
                formatsList.sort { $0.sortKey > $1.sortKey }
                
                var uniqueFormats: [VideoFormat] = []
                var seenLabels = Set<String>()
                for format in formatsList {
                    if !seenLabels.contains(format.resolution) {
                        seenLabels.insert(format.resolution)
                        uniqueFormats.append(format)
                    }
                }
                
                DispatchQueue.main.async {
                    self.videoTitle = title
                    self.editableTitle = title
                    self.editableAuthor = author
                    self.thumbnailURL = thumbnail
                    self.videoDuration = durationFormatted
                    self.availableFormats = uniqueFormats
                    if self.selectedFormat == nil {
                        self.selectedFormat = uniqueFormats.first
                        if let firstFormat = uniqueFormats.first {
                            self.selectedContainer = firstFormat.isAudioOnly ? "mp3" : "mp4"
                        }
                    }
                    self.outputLog += "[完了] 解析が正常に終了しました。\n"
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.outputLog += "[エラー] \(error.localizedDescription)\n"
                }
            }
        }
    }
    
    func downloadVideoWithSavePanel(url: String) {
        guard let selected = selectedFormat else { return }
        
        let savePanel = NSSavePanel()
        let selectedExt = selectedContainer.lowercased()
        
        if selectedExt == "mp3" { savePanel.allowedContentTypes = [.mp3] }
        else if selectedExt == "m4a" { savePanel.allowedContentTypes = [.mpeg4Audio] }
        else if selectedExt == "mkv" {
            if let mkvType = UTType(filenameExtension: "mkv") { savePanel.allowedContentTypes = [mkvType] }
            else { savePanel.allowedContentTypes = [.movie] }
        } else { savePanel.allowedContentTypes = [.mpeg4Movie] }
        
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        let safeTitle = editableTitle.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let safeAuthor = editableAuthor.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let fileName = safeAuthor.isEmpty ? "\(safeTitle).\(selectedExt)" : "\(safeAuthor) - \(safeTitle).\(selectedExt)"
        
        savePanel.nameFieldStringValue = fileName
        
        savePanel.begin { response in
            if response == .OK, let targetURL = savePanel.url {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.startDownload(url: url, formatId: selected.id, destinationURL: targetURL)
                }
            }
        }
    }
    
    private func startDownload(url: String, formatId: String, destinationURL: URL) {
        isDownloading = true
        downloadProgress = 0.0
        downloadSpeed = ""
        downloadETA = ""
        downloadStatus = "downloading"
        lastDestinationFolderURL = destinationURL.deletingLastPathComponent()
        outputLog += "\n[ダウンロード開始] \(editableTitle)\n保存先: \(destinationURL.path)\n"
        
        let ytdlpPath = getYTDlpPath()
        let process = Process()
        self.process = process
        
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        process.environment = env
        
        var formatArg = formatId
        if !formatId.contains("+") && !formatId.contains("ba") && !formatId.contains("wa") {
            formatArg = "\(formatId)+bestaudio/best"
        }
        
        var args = [
            "-f", formatArg,
            "-o", destinationURL.path,
            "--no-playlist",
            "--force-ipv4"
        ]
        
        args.append("--embed-metadata")
        
        if !editableTitle.isEmpty {
            args.append(contentsOf: [
                "--parse-metadata", ":(?P<title>\(editableTitle))"
            ])
        }
        if !editableAuthor.isEmpty {
            args.append(contentsOf: [
                "--parse-metadata", ":(?P<artist>\(editableAuthor))",
                "--parse-metadata", ":(?P<uploader>\(editableAuthor))",
                "--parse-metadata", ":(?P<album_artist>\(editableAuthor))"
            ])
        }
        
        if shouldDownloadThumbnail {
            args.append("--embed-thumbnail")
        }
        
        let ext = selectedContainer.lowercased()
        let isAudio = selectedFormat?.isAudioOnly ?? false
        
        if isAudio {
            args.append(contentsOf: ["--extract-audio", "--audio-format", ext])
        } else {
            args.append(contentsOf: ["--merge-output-format", ext])
        }
        
        args.append(url)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.waitForDataInBackgroundAndNotify()
        
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSFileHandleDataAvailable,
            object: fileHandle, queue: nil
        ) { _ in
            let data = fileHandle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.outputLog += output
                        self.parseProgress(from: output)
                    }
                }
                fileHandle.waitForDataInBackgroundAndNotify()
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try process.run()
                process.waitUntilExit()
                
                let status = process.terminationStatus
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    if status == 0 {
                        self.downloadProgress = 1.0
                        self.downloadStatus = "success"
                        self.outputLog += "\n[完了] ダウンロードが成功しました！\n"
                    } else {
                        self.downloadStatus = "error"
                        self.lastDestinationFolderURL = nil
                        self.outputLog += "\n[完了] プロセス失敗。コード: \(status)\n"
                    }
                }
            } catch {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.lastDestinationFolderURL = nil
                    self.downloadStatus = "error"
                    self.outputLog += "\n[エラー] \(error.localizedDescription)\n"
                }
            }
        }
    }
    
    private func parseProgress(from text: String) {
        let pattern = "\\[download\\]\\s+(\\d+\\.\\d+)%\\s+of\\s+.*?\\s+at\\s+(\\S+)\\s+ETA\\s+(\\S+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
            if let pctRange = Range(match.range(at: 1), in: text), let pctDouble = Double(text[pctRange]) {
                self.downloadProgress = pctDouble / 100.0
            }
            if let speedRange = Range(match.range(at: 2), in: text) { self.downloadSpeed = String(text[speedRange]) }
            if let etaRange = Range(match.range(at: 3), in: text) { self.downloadETA = String(text[etaRange]) }
        }
    }
    
    func stopDownload() {
        if process?.isRunning == true {
            process?.terminate()
            downloadStatus = "canceled"
            outputLog += "\n[中断] ユーザーによって処理が停止されました。\n"
        }
    }
}
