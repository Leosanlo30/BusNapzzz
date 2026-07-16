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
                guard let coordinates = feature.geometry.coordinates else { return nil }
                let longitude = coordinates[0]
                let latitude = coordinates[1]

                let name: String
                if let directName = feature.properties.name, !directName.isEmpty {
                    name = directName
                } else if let firstRelation = feature.properties.relations?.first,
                          let routeName = firstRelation.reltags["name"] {
                    name = routeName
                } else {
                    name = "Parada \(feature.id ?? "desconocida")"
                }

                let stopId = feature.id ?? "node_\(latitude)_\(longitude)"

                return BusStop(
                    id: stopId,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
            }

        if stops.isEmpty {
            throw GeoJSONError.noFeaturesFound
        }

        return stops
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
