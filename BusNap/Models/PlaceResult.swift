import Foundation
import MapKit
import Contacts

// MARK: - PlaceResult

/// Resultado de una búsqueda MKLocalSearch, conforme a Codable para persistencia offline.
///
/// Extrae los datos usando `location`, `address` y `addressRepresentations` en lugar de
/// la propiedad `title` (deprecated) de `MKPlacemark`.
struct PlaceResult: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    // AQUI: Refactorización de placemark a la API moderna de MapKit para eliminar advertencias de deprecación.
    init(mapItem: MKMapItem) {
        let coord: CLLocationCoordinate2D
        if #available(iOS 26.0, *) {
            coord = mapItem.location?.coordinate ?? mapItem.coordinate
        } else {
            coord = mapItem.placemark.location?.coordinate ?? mapItem.placemark.coordinate
        }
        let lat = coord.latitude
        let lng = coord.longitude
        self.id = "place_\(lat)_\(lng)"
        self.name = mapItem.name ?? "Lugar"

        if #available(iOS 26.0, *) {
            if let postal = mapItem.address {
                self.subtitle = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
            } else {
                self.subtitle = ""
            }
        } else {
            if let postal = mapItem.placemark.postalAddress {
                self.subtitle = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
            } else {
                self.subtitle = ""
            }
        }

        self.latitude = lat
        self.longitude = lng
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
