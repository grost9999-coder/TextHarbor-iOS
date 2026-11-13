import Foundation

struct ExtractedDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var source: String
    var kind: String
    var createdAt = Date()
    var updatedAt = Date()
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var documents: [ExtractedDocument] = []
    @Published var lastError: String?
    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("text-harbor-library.json")
        do {
            let data = try Data(contentsOf: fileURL)
            documents = try JSONDecoder().decode([ExtractedDocument].self, from: data)
        } catch {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                lastError = "無法讀取資料庫：\(error.localizedDescription)"
            }
        }
    }

    func upsert(_ document: ExtractedDocument) {
        var updated = document
        updated.updatedAt = .now
        if let index = documents.firstIndex(where: { $0.id == updated.id }) {
            documents[index] = updated
        } else {
            documents.insert(updated, at: 0)
        }
        persist()
    }

    func remove(_ offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "儲存失敗：\(error.localizedDescription)"
        }
    }
}
