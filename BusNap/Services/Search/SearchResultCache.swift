//
//  SearchResultCache.swift
//  BusNap
//

import Foundation

/// Caché LRU acotada de resultados de búsqueda, para usar sin conexión.
///
/// - Vive en `Caches/` (no se respalda en iCloud y el sistema puede purgarla).
/// - Normaliza la consulta (mayúsculas, acentos, espacios) para aprovechar más aciertos.
/// - Se lee del disco una sola vez y escribe en segundo plano.
@MainActor
final class SearchResultCache {

    private struct Entry: Codable {
        let key: String
        let results: [PlaceResult]
    }

    private let fileURL: URL?
    private let capacity: Int
    private var entries: [Entry]?

    init(fileURL: URL? = SearchResultCache.defaultFileURL, capacity: Int = 50) {
        self.fileURL = fileURL
        self.capacity = capacity
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("search_cache.json")
    }

    nonisolated static func key(for query: String) -> String {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    func results(for query: String) -> [PlaceResult]? {
        let key = Self.key(for: query)
        return loadedEntries().first { $0.key == key }?.results
    }

    func store(_ results: [PlaceResult], for query: String) {
        guard !results.isEmpty else { return }
        let key = Self.key(for: query)
        var current = loadedEntries()
        current.removeAll { $0.key == key }
        current.insert(Entry(key: key, results: results), at: 0)
        if current.count > capacity { current.removeLast(current.count - capacity) }
        entries = current
        persist(current)
    }

    // MARK: - Private

    private func loadedEntries() -> [Entry] {
        if let entries { return entries }
        let loaded = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        entries = loaded
        return loaded
    }

    private func persist(_ entries: [Entry]) {
        guard let fileURL, let data = try? JSONEncoder().encode(entries) else { return }
        Task.detached(priority: .utility) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
