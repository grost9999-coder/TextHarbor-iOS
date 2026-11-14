import SwiftUI
import PhotosUI
import WebKit
import UniformTypeIdentifiers

private enum CaptureMode: String, CaseIterable, Identifiable {
    case video = "影片畫面"
    case speech = "影片語音"
    case subtitles = "影片字幕"
    case images = "截圖／照片"
    case web = "網頁網址"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .video: return "film.stack"
        case .speech: return "waveform"
        case .subtitles: return "captions.bubble"
        case .images: return "photo.on.rectangle"
        case .web: return "globe"
        }
    }
}

struct ExtractView: View {
    @State private var mode: CaptureMode = .video
    @State private var videoSelection: PhotosPickerItem?
    @State private var imageSelections: [PhotosPickerItem] = []
    @State private var selectedVideo: URL?
    @State private var chosenImages: [UIImage] = []
    @State private var sourceLabel = ""
    @State private var urlInput = ""
    @State private var locale = "zh-TW"
    @State private var importingFiles = false
    @State private var importingImages = false
    @State private var processing = false
    @State private var progress = 0.0
    @State private var resultText = ""
    @State private var videoStats: VideoOCRStats?
    @State private var mergedVideoText = ""
    @State private var viewingRawVideoText = false
    @State private var showAllResult = false
    @State private var resultDoc: ExtractedDocument?
    @State private var alertMessage: String?
    @StateObject private var web = WebExtractor()
    @State private var speech = SpeechService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("選擇擷取來源").font(.headline)
                    modeGrid
                    sourceControls
                    if processing {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress)
                            Text("正在辨識… \(Int(progress * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button(action: startExtraction) {
                        Label(processing ? "辨識中" : "開始擷取文字", systemImage: "text.viewfinder")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(processing || !hasSource)
                    resultSection
                    videoDiagnostics
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("文字擷取")
            .onChange(of: videoSelection) { _, selected in
                guard let selected else { return }
                Task {
                    do {
                        guard let movie = try await selected.loadTransferable(type: ImportedMovie.self) else {
                            alertMessage = "無法匯入影片。"
                            return
                        }
                        selectedVideo = movie.url
                        sourceLabel = movie.url.lastPathComponent
                    } catch { alertMessage = error.localizedDescription }
                }
            }
            .onChange(of: imageSelections) { _, selected in
                Task {
                    var images: [UIImage] = []
                    for item in selected {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) { images.append(image) }
                    }
                    chosenImages = images
                    sourceLabel = "\(images.count) 張照片／截圖"
                }
            }
            .fileImporter(isPresented: $importingFiles,
                          allowedContentTypes: [.movie, .video, .mpeg4Movie], allowsMultipleSelection: false) { result in
                do {
                    guard let original = try result.get().first else { return }
                    let accessed = original.startAccessingSecurityScopedResource()
                    defer { if accessed { original.stopAccessingSecurityScopedResource() } }
                    let target = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(original.pathExtension)
                    try FileManager.default.copyItem(at: original, to: target)
                    selectedVideo = target
                    sourceLabel = original.lastPathComponent
                } catch { alertMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $importingImages,
                          allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                do {
                    var images: [UIImage] = []
                    for url in try result.get() {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        if let image = UIImage(contentsOfFile: url.path) { images.append(image) }
                    }
                    chosenImages = images
                    sourceLabel = "\(images.count) 張圖片"
                } catch { alertMessage = error.localizedDescription }
            }
            .navigationDestination(item: $resultDoc) { EditorView(document: $0) }
            .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("確定", role: .cancel) { alertMessage = nil }
            } message: { Text(alertMessage ?? "") }
        }
    }

    private var modeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(CaptureMode.allCases) { item in
                Button {
                    mode = item
                    resultText = ""
                    videoStats = nil
                    mergedVideoText = ""
                    viewingRawVideoText = false
                    showAllResult = false
                } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(.subheadline).fontWeight(.medium)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(mode == item ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(mode == item ? Color.accentColor : Color.clear, lineWidth: 1.5))
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var resultSection: some View {
        if !resultText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("辨識結果").font(.headline)
                    Spacer()
                    Text("\(resultText.count) 字").font(.caption).foregroundStyle(.secondary)
                }
                Text(resultText).font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(showAllResult ? nil : 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if resultText.components(separatedBy: .newlines).count > 14 {
                    Button(showAllResult ? "收合預覽" : "展開完整辨識文字") { showAllResult.toggle() }
                        .font(.footnote)
                }
                HStack {
                    Button("複製") { UIPasteboard.general.string = resultText }.buttonStyle(.bordered)
                    Button("編輯與儲存") { createDocument() }.buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder private var videoDiagnostics: some View {
        if let info = videoStats {
            VStack(alignment: .leading, spacing: 5) {
                Text("影片辨識報告").font(.headline)
                Text("抽樣影格：\(info.requestedFrames)｜已分析：\(info.analyzedFrames)｜失敗：\(info.failedFrames)")
                Text("OCR 原始行數：\(info.detectedLines)｜合併後行數：\(info.retainedLines)")
                Text("旋轉方向辨識影格：\(info.rotatedFrames)")
                if !info.rawText.isEmpty {
                    Button(viewingRawVideoText ? "回到合併後文字" : "查看未去重原始文字") {
                        if !viewingRawVideoText { mergedVideoText = resultText }
                        viewingRawVideoText.toggle()
                        resultText = viewingRawVideoText ? info.rawText : mergedVideoText
                    }.buttonStyle(.bordered)
                    Text("原始文字含重複影格及時間標記，可用來比對漏字；切換後也可複製及儲存。")
                        .foregroundStyle(.secondary)
                }
                Text("文字若仍不完整，請改用慢速捲動且停留在清晰畫面的原始影片，或將影片分段辨識並人工校對。")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder private var sourceControls: some View {
        switch mode {
        case .video, .speech, .subtitles:
            VStack(alignment: .leading, spacing: 12) {
                Text("從相簿選擇螢幕錄影或一般影片").font(.subheadline)
                PhotosPicker(selection: $videoSelection, matching: .videos) {
                    Label("從相簿選擇影片", systemImage: "photo.on.rectangle.angled")
                }.buttonStyle(.bordered)
                Button("從檔案選擇影片", systemImage: "folder") { importingFiles = true }.buttonStyle(.bordered)
                if !sourceLabel.isEmpty && selectedVideo != nil {
                    Label(sourceLabel, systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(.green)
                }
                if mode == .speech {
                    Picker("語音語言", selection: $locale) {
                        Text("繁體中文").tag("zh-TW")
                        Text("English").tag("en-US")
                        Text("日本語").tag("ja-JP")
                    }.pickerStyle(.segmented)
                    Text("語音辨識可能需要網路連線；長片或背景音樂會影響結果。")
                        .font(.caption).foregroundStyle(.secondary)
                } else if mode == .subtitles {
                    Text("主要辨識畫面下方 35% 的字幕；字幕若在其他位置請改用「影片畫面」。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("完整擷取模式：約每 0.3 秒抽樣一格，最多分析 1,500 格；影片過快捲動仍可能漏字。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .images:
            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $imageSelections, maxSelectionCount: 30, matching: .images) {
                    Label("從相簿選擇照片／截圖", systemImage: "photo.stack")
                }.buttonStyle(.bordered)
                Button("從檔案選擇圖片", systemImage: "folder") { importingImages = true }.buttonStyle(.bordered)
                Text("已選擇 \(chosenImages.count) 張；將依選取順序合併文字。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .web:
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com/article", text: $urlInput)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button("開啟網址", systemImage: "globe") { web.open(urlInput) }.buttonStyle(.bordered)
                Text(web.message).font(.caption).foregroundStyle(.secondary)
                WebPreview(webView: web.webView)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2)))
                Text("需要登入的網頁可先在上方預覽視窗完成登入；無法繞過網站存取限制。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var hasSource: Bool {
        switch mode {
        case .video, .speech, .subtitles: return selectedVideo != nil
        case .images: return !chosenImages.isEmpty
        case .web: return !web.isLoading && web.webView.url != nil
        }
    }
    private func startExtraction() {
        processing = true
        progress = 0
        resultText = ""
        videoStats = nil
        mergedVideoText = ""
        viewingRawVideoText = false
        showAllResult = false
        let finish: (Result<String, Error>) -> Void = { result in
            processing = false
            progress = 1
            switch result {
            case .success(let text):
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    alertMessage = ExtractionError.noText.localizedDescription
                } else { resultText = text }
            case .failure(let error): alertMessage = error.localizedDescription
            }
        }
        switch mode {
        case .video, .subtitles:
            guard let selectedVideo else { processing = false; return }
            OCRService.recognizeVideo(selectedVideo, subtitleOnly: mode == .subtitles,
                                      progress: { progress = $0 },
                                      stats: { videoStats = $0 }, completion: finish)
        case .speech:
            guard let selectedVideo else { processing = false; return }
            speech.transcribe(videoURL: selectedVideo, locale: locale, completion: finish)
        case .images:
            OCRService.recognizeImages(chosenImages, progress: { progress = $0 }, completion: finish)
        case .web:
            web.extract(completion: finish)
        }
    }
    private func createDocument() {
        resultDoc = ExtractedDocument(
            title: mode == .web ? (web.title.isEmpty ? "網頁文字" : web.title) : "\(mode.rawValue) \(Date().formatted(date: .numeric, time: .shortened))",
            text: resultText,
            source: mode == .web ? (web.webView.url?.absoluteString ?? urlInput) : sourceLabel,
            kind: mode.rawValue
        )
    }
}

private struct WebPreview: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
