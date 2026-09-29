//
//  PlaceSearchService.swift
//  BusNap
//

import OSLog
import Foundation
import MapKit
import Observation

/// Sugerencia de autocompletado mientras el usuario escribe.
struct PlaceSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

/// Búsqueda de lugares: autocompletado en vivo + búsqueda completa con caché offline.
@MainActor
protocol PlaceSearching: AnyObject {
    /// Sugerencias del autocompletado para la consulta actual.
    var suggestions: [PlaceSuggestion] { get }
    func updateQuery(_ query: String, region: MKCoordinateRegion?)
    /// Búsqueda completa. Primero red; si falla, caché.
    func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceResult]
    /// Convierte una sugerencia en un lugar con coordenadas.
    func resolve(_ suggestion: PlaceSuggestion) async throws -> PlaceResult?
    /// Nombre legible de una coordenada (geocodificación inversa).
    func name(for coordinate: CLLocationCoordinate2D) async -> String?
}

@MainActor
@Observable
final class PlaceSearchService: NSObject, PlaceSearching {

    private(set) var suggestions: [PlaceSuggestion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    @ObservationIgnored private let cache: SearchResultCache

    init(cache: SearchResultCache? = nil) {
        self.cache = cache ?? SearchResultCache()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String, region: MKCoordinateRegion?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completer.cancel()
            suggestions = []
            completionsByID = [:]
            return
        }
        if let region { completer.region = region }
        // MKLocalSearchCompleter ya limita la frecuencia de peticiones internamente.
        completer.queryFragment = trimmed
    }

    func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }

        do {
            let response = try await MKLocalSearch(request: request).start()
            let results = response.mapItems.map(PlaceResult.init(mapItem:))
            cache.store(results, for: query)
            return results
        } catch {
            if let cached = cache.results(for: query) {
                Log.search.info("Búsqueda sin red: usando caché")
                return cached
            }
            throw error
        }
    }

    func resolve(_ suggestion: PlaceSuggestion) async throws -> PlaceResult? {
        guard let completion = completionsByID[suggestion.id] else { return nil }
        let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
        return response.mapItems.first.map(PlaceResult.init(mapItem:))
    }

    func name(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let item = try? await request.mapItems.first
        return item?.name
    }

    fileprivate func apply(_ results: [MKLocalSearchCompletion]) {
        var byID: [String: MKLocalSearchCompletion] = [:]
        var items: [PlaceSuggestion] = []
        for completion in results.prefix(8) {
            let id = "\(completion.title)|\(completion.subtitle)"
            guard byID[id] == nil else { continue }
            byID[id] = completion
            items.append(PlaceSuggestion(id: id, title: completion.title, subtitle: completion.subtitle))
        }
        completionsByID = byID
        suggestions = items
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension PlaceSearchService: MKLocalSearchCompleterDelegate {

    // MKLocalSearchCompleter entrega sus callbacks en el hilo principal.
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            apply(completer.results)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Log.search.error("Autocompletado falló: \(error.localizedDescription, privacy: .public)")
    }
}
