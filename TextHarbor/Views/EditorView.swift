import SwiftUI
import UIKit

struct EditorView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var document: ExtractedDocument
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showExportOptions = false
    @State private var errorMessage: String?

    init(document: ExtractedDocument) {
        _document = State(initialValue: document)
    }

    var body: some View {
        Form {
            Section("標題") { TextField("文件標題", text: $document.title) }
            Section("擷取文字（可修改）") {
                TextEditor(text: $document.text)
                    .frame(minHeight: 350)
                    .font(.body)
                    .textInputAutocapitalization(.never)
            }
            Section {
                HStack {
                    Button("複製全文", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = document.text
                    }
                    Spacer()
                    Button("匯出檔案", systemImage: "square.and.arrow.up") {
                        showExportOptions = true
                    }
                }
                Text("來源：\(document.source)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("編輯文件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("儲存") {
                    library.upsert(document)
                    dismiss()
                }.fontWeight(.semibold)
            }
        }
        .confirmationDialog("選擇匯出格式", isPresented: $showExportOptions) {
            Button("文字檔 TXT") { export(pdf: false) }
            Button("PDF 文件") { export(pdf: true) }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL { ActivitySheet(items: [shareURL]) }
        }
        .alert("匯出失敗", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("確定", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func export(pdf: Bool) {
        do {
            shareURL = try ExportService.makeFile(document: document, pdf: pdf)
            showShare = true
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
