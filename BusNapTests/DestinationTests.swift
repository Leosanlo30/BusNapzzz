import Testing
@testable import BusNap

@Suite("Destination")
struct DestinationTests {

    @Test func nameIsNilByDefault() {
        let destination = Destination(latitude: 19.4326, longitude: -99.1332)
        #expect(destination.name == nil)
    }

    @Test func storesProvidedName() {
        let destination = Destination(name: "CDMX", latitude: 19.4326, longitude: -99.1332)
        #expect(destination.name == "CDMX")
    }

    @Test func storesLatitudeAndLongitude() {
        let destination = Destination(latitude: 19.4326, longitude: -99.1332)
        #expect(destination.latitude == 19.4326)
        #expect(destination.longitude == -99.1332)
    }

    @Test func equalWhenCoordinatesAndNameMatch() {
        let a = Destination(name: "Home", latitude: 19.4326, longitude: -99.1332)
        let b = Destination(name: "Home", latitude: 19.4326, longitude: -99.1332)
        #expect(a == b)
    }

    @Test func notEqualWhenCoordinatesDiffer() {
        let a = Destination(latitude: 19.4326, longitude: -99.1332)
        let b = Destination(latitude: 20.0000, longitude: -99.1332)
        #expect(a != b)
    }
}
