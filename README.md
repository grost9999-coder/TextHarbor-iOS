# 擷字匣 TextHarbor

iPhone 原生 SwiftUI 文字擷取 App（iOS 17+）

## 功能
- 影片畫面 OCR
- 影片下方字幕 OCR
- 影片音軌轉文字（Apple Speech）
- 照片及截圖批次辨識
- 網頁內文擷取
- 按畫面順序合併、去除重複文字
- 編輯、複製、本機文件庫、全文搜尋、TXT 與 PDF 匯出

## 建置與安裝
使用 Xcode 開啟 `TextHarbor.xcodeproj`，選取 `TextHarbor` Scheme。
GitHub Actions 在 macOS runner 執行不需要簽署的 iOS Simulator 編譯檢查。
要安裝到 iPhone 或上傳 TestFlight，另外需要設定 Apple Developer 帳號與簽署，並建立發布工作流程。

## 限制
文字辨識仍須人工校對，影片抽樣可能遺漏閃現字幕。部分網頁禁止存取。
此專案目前仍在驗證編譯階段，不代表已通過實機或 TestFlight 測試。

## 隱私
照片與影片畫面 OCR 使用 Apple Vision 裝置端處理；語音辨識服務可能需要網路。擷取文件儲存在 App 本機沙盒，刪除 App 可能失去文件，請定期匯出備份。
