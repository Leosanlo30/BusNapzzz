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
}
