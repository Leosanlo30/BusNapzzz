import CoreLocation

struct Destination: Equatable, Hashable, Codable {
    var name: String?
    var latitude: Double
    var longitude: Double
    var icon: String?

    init(name: String? = nil, latitude: Double, longitude: Double, icon: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.icon = icon
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Dos destinos son "el mismo lugar" si están a menos de ~10 m.
    /// Evita duplicados en favoritos y recientes por diferencias de redondeo.
    func isSamePlace(as other: Destination) -> Bool {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude)) < 10
    }
}
