import Foundation

enum TripUIState: Equatable {
    case initial
    case configuring
    case active
    case paused
    case finished

    static func from(engineState: TripState, isPaused: Bool) -> TripUIState {
        switch engineState {
        case .idle:
            return .initial
        case .configured:
            return .configuring
        case .monitoring, .criticalZone:
            return isPaused ? .paused : .active
        case .alarmTriggered:
            return .finished
        case .cancelled:
            return .initial
        }
    }
}
