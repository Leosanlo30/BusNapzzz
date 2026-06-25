struct Destination: Equatable, Hashable, Codable {
    var name: String?
    var latitude: Double
    var longitude: Double

    init(name: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
