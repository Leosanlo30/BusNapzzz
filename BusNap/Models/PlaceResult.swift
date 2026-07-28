import Foundation
import MapKit

// MARK: - PlaceResult

/// Resultado de una búsqueda MKLocalSearch, conforme a Codable para persistencia offline.
struct PlaceResult: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    init(mapItem: MKMapItem) {
        let lat = mapItem.placemark.coordinate.latitude
        let lng = mapItem.placemark.coordinate.longitude
        self.id = "place_\(lat)_\(lng)"
        self.name = mapItem.name ?? "Lugar"
        self.subtitle = mapItem.placemark.title ?? ""
        self.latitude = lat
        self.longitude = lng
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
