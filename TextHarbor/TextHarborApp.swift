import SwiftUI

@main
struct TextHarborApp: App {
    @StateObject private var library = LibraryStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                ExtractView()
                    .tabItem { Label("文字擷取", systemImage: "text.viewfinder") }
                LibraryView()
                    .tabItem { Label("文件庫", systemImage: "books.vertical") }
                NavigationStack {
                    List {
                        Section("支援的擷取") {
                            Text("影片畫面 OCR／影片字幕 OCR／影片語音辨識")
                            Text("照片與截圖 OCR／網頁文字擷取")
                        }
                        Section("儲存與隱私") {
                            Text("擷取文件以 JSON 儲存在本機 App 沙盒。")
                            Text("照片與影片畫面 OCR 使用 Apple Vision 在裝置上執行。")
                            Text("Apple 語音辨識可能經由網路處理。")
                            Text("刪除 App 可能同時刪除本機文件，請定期匯出備份。")
                        }
                        Section("使用提醒") {
                            Text("請尊重網站、影片與文件的著作權、個資及使用條款。")
                            Text("影片 OCR 為抽樣辨識，極短暫的字幕可能漏抓；文字仍需校對。")
                        }
                    }
                    .navigationTitle("關於")
                }.tabItem { Label("關於", systemImage: "info.circle") }
            }
            .environmentObject(library)
            .alert("資料庫提示", isPresented: Binding(get: { library.lastError != nil }, set: { if !$0 { library.lastError = nil } })) {
                Button("確定", role: .cancel) { library.lastError = nil }
            } message: { Text(library.lastError ?? "") }
        }
    }
}
