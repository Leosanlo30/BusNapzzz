import Foundation
import CoreLocation

struct BusStop: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: BusStop, rhs: BusStop) -> Bool {
        lhs.id == rhs.id
    }
}
