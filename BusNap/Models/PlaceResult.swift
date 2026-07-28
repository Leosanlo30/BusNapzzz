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

    // AQUI: Corrección de errores de compilación de la nueva API de MapKit.
    init(mapItem: MKMapItem) {
        let coord: CLLocationCoordinate2D
        if #available(iOS 26.0, *) {
            coord = mapItem.location.coordinate
        } else {
            coord = mapItem.placemark.location?.coordinate ?? mapItem.placemark.coordinate
        }
        let lat = coord.latitude
        let lng = coord.longitude
        self.id = "place_\(lat)_\(lng)"
        self.name = mapItem.name ?? "Lugar"

        if #available(iOS 26.0, *) {
            // MKAddress replaces CNPostalAddress; build string from its components
            if let addr = mapItem.address {
                var parts: [String] = []
                if let s = addr.street { parts.append(s) }
                if let c = addr.city { parts.append(c) }
                if let st = addr.state { parts.append(st) }
                self.subtitle = parts.joined(separator: ", ")
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
