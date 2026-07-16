import Foundation
import CoreLocation

enum GeoJSONError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidData
    case decodingFailed(Error)
    case noFeaturesFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name): return "GeoJSON file '\(name)' not found in bundle."
        case .invalidData: return "GeoJSON data is invalid or corrupted."
        case .decodingFailed(let error): return "Failed to decode GeoJSON: \(error.localizedDescription)"
        case .noFeaturesFound: return "No Point features found in the GeoJSON file."
        }
    }
}

@MainActor
final class GeoJSONManager {

    static let shared = GeoJSONManager()
    private init() {}

    func loadBusStops(from fileName: String, in bundle: Bundle = .main) throws -> [BusStop] {
        guard let url = bundle.url(forResource: fileName, withExtension: "geojson") else {
            throw GeoJSONError.fileNotFound(fileName)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GeoJSONError.invalidData
        }

        let decoder = JSONDecoder()
        let featureCollection: FeatureCollection
        do {
            featureCollection = try decoder.decode(FeatureCollection.self, from: data)
        } catch {
            throw GeoJSONError.decodingFailed(error)
        }

        let stops = featureCollection.features
            .filter { $0.geometry.type == "Point" }
            .compactMap { feature -> BusStop? in
                guard let coords = feature.geometry.coordinates, coords.count >= 2 else { return nil }
                let longitude = coords[0]
                let latitude = coords[1]

                let stopId = feature.id ?? "node_\(latitude)_\(longitude)"

                let routeNames: [String] = feature.properties.relations?
                    .compactMap { rel in rel.reltags["name"] }
                    .uniqued() ?? []

                let name: String = {
                    if let directName = feature.properties.name, !directName.isEmpty {
                        return directName
                    }
                    if let firstRoute = routeNames.first {
                        return firstRoute
                    }
                    return "Parada \(stopId)"
                }()

                return BusStop(
                    id: stopId,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    routeNames: routeNames
                )
            }

        if stops.isEmpty {
            throw GeoJSONError.noFeaturesFound
        }

        return stops
    }
}

// MARK: - Unique Helper

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - GeoJSON Codable Models

private struct FeatureCollection: Decodable {
    let type: String
    let features: [Feature]
}

private struct Feature: Decodable {
    let type: String
    let geometry: Geometry
    let properties: Properties
    let id: String?
}

private struct Geometry: Decodable {
    let type: String
    let coordinates: [Double]?
}

private struct Properties: Decodable {
    let name: String?
    let relations: [Relation]?

    enum CodingKeys: String, CodingKey {
        case name
        case relations = "@relations"
    }
}

private struct Relation: Decodable {
    let role: String
    let rel: Int
    let reltags: [String: String]
}
