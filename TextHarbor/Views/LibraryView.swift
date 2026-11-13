import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var search = ""
    private var filtered: [ExtractedDocument] {
        guard !search.isEmpty else { return library.documents }
        return library.documents.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.text.localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { doc in
                    NavigationLink {
                        EditorView(document: doc)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(doc.title).font(.headline)
                            Text(doc.text).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                            HStack {
                                Text(doc.kind)
                                Spacer()
                                Text(doc.updatedAt, style: .date)
                            }.font(.caption).foregroundStyle(.tertiary)
                        }.padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { filtered[$0].id }
                    let original = IndexSet(library.documents.indices.filter { ids.contains(library.documents[$0].id) })
                    library.remove(original)
                }
            }
            .overlay {
                if library.documents.isEmpty {
                    ContentUnavailableView("尚無文件", systemImage: "doc.text", description: Text("擷取完成後按「編輯與儲存」即可加入文件庫。"))
                }
            }
            .searchable(text: $search, prompt: "搜尋標題或全文")
            .navigationTitle("我的文件")
        }
    }
}
