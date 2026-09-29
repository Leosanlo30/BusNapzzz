# BusNap

**Native iOS public transit alighting alarm.** Pick where you get off, start the trip, and fall asleep: BusNap wakes you up before your stop — even with the screen locked — using geofences and adaptive GPS to save battery.

---

## Purpose — What Exactly the Project Solves

- **Arrival alarm with two triggers** — `TripEngine` fires the alarm when you enter a geofence sized from your lead time (≈ minutes × average bus speed), with a 100 m GPS threshold as a backup. The transition is idempotent: only the first trigger rings.
- **Survives app termination** — the active trip is persisted (`ActiveTripStore`). If iOS relaunches the app from a geofence event, the trip is restored; orphan geofences from old sessions are purged on launch.
- **Adaptive GPS, only during a trip** — `AdaptiveLocationManager` is off until you start a trip, then switches accuracy by distance (3 km → 1 km → navigation-grade under 1 km). In the background it saves battery far from the stop but never near it. Automatic pausing is disabled so a bus stuck in traffic doesn't lose tracking.
- **Apple Maps–style search** — live autocomplete (`MKLocalSearchCompleter`), full search with a bounded offline cache (`Caches/`, LRU, accent-insensitive), favorites, and recent trips. Tapping the map reverse-geocodes the point's name.
- **Map settings** — Explore / Transit / Hybrid / Satellite styles, public-transport stops, traffic, 3D buildings, follow-me during the trip, and distance units. Route line and alarm-zone circle drawn on the map.
- **Alarm settings** — ringtone with preview, vibration toggle (actually honored), custom lead time, and a "test alarm" button. Audio resumes after interruptions (calls, Siri) and only ducks other audio while the alarm rings.
- **Permission UX** — requests "When in use" on launch, upgrades to "Always" when starting a trip (the trip starts automatically once granted), requests notification permission, and offers a shortcut to iOS Settings when something is missing.

- Frequently forget which bus stop they need to get off at.
- Want to be alerted automatically when their bus is approaching, even while using other apps or with the screen locked.
- Need a battery-efficient solution that adapts GPS polling frequency based on distance to destination.

## Tech Stack

| Layer             | Technology |
|-------------------|------------|
| Language          | Swift 5 mode, Xcode 26 |
| UI Framework      | SwiftUI (iOS 26.2+) |
| Architecture      | MVVM with `@Observable`, protocol-based dependency injection |
| Maps              | MapKit (`Map`, `MapPolyline`, `MapCircle`, `mapScope` controls, `MKLocalSearchCompleter`, `MKReverseGeocodingRequest`) |
| Location          | CoreLocation (`CLLocationManager`, `CLCircularRegion`) |
| Persistence       | `UserDefaults` via `AppSettings`, `UserPreferencesStoring`, `ActiveTripStoring` |
| Concurrency       | `async/await`, cancellable `Task`s, `@MainActor` |
| Notifications     | `UNUserNotificationCenter` (time-sensitive) |
| Logging           | `os.Logger` (`Log.trip`, `Log.location`, …) with private-by-default interpolation |

---

## Documentation: Clone Repo to Test

### Prerequisites

- Xcode 26.2+
- iOS 26.2+ (deployment target)
- No third-party dependencies — system frameworks only.

### Run

```bash
# Clone the repository
git clone https://github.com/Leosanlo30/BusNapzzz.git
cd BusNapzzz

# Switch to the rutas_Merida branch (Merida bus route data)
git checkout rutas_Merida

# Open in Xcode
open BusNap.xcodeproj
```

1. Select a simulator or device and run (`Cmd+R`).
2. Allow location **"While Using"** at launch, then **"Always"** when starting the first trip — required for background alarms.
3. Allow notifications so the alarm is visible on the lock screen.
4. Search for a place or tap the map, choose the lead time, and press **Iniciar viaje**.

### Simulating a trip

`BusNap/TestRoutes/` contains GPX files (e.g. `RutaVaYVenCanek.gpx`). In Xcode: *Debug → Simulate Location → Add GPX File to Workspace…*, pick one, and set your destination along the route to hear the alarm without leaving your desk.

### Tests

```bash
xcodebuild test -project BusNap.xcodeproj -scheme BusNap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BusNapTests CODE_SIGNING_ALLOWED=NO
```

Unit tests use in-memory mocks for location, geofences, notifications, audio, and storage (`BusNapTests/Mocks/`) — no real hardware, `UserDefaults.standard`, or sound. The same command runs in GitHub Actions (`.github/workflows/swift.yml`).

### GeoJSON Data

`Resources/Navigation/` bundles OpenStreetMap-derived Mérida bus stop and route data (`PARADEROS_MERIDA.geojson`, `RUTAS_Merida*.geojson`), parsed by `GeoJSONManager`. Stop display is currently disabled in the UI and planned for reactivation.

---

## Project Structure

```
BusNap/
├── BusNapApp.swift              # App entry point
├── Core/
│   ├── Logging/                 # os.Logger categories
│   ├── TripEngine/              # Trip state machine + alarm dispatch
│   ├── Theme/                   # AppConstants, ThemeManager, glass modifiers
│   ├── Storage/                 # AppSettings, preferences, active-trip persistence
│   └── UIComponents/            # Reusable SwiftUI views
├── Features/
│   ├── MapDashboard/            # Main screen: ViewModel, map canvas, bottom sheet
│   └── Settings/                # Alarm, map, permissions, appearance
├── Models/                      # Destination, AlertLeadTime, PlaceResult, …
├── Resources/                   # GeoJSON, alarm sounds
├── Services/
│   ├── Location/                # AdaptiveLocationManager, GeofenceMonitor
│   ├── Routing/                 # MapKit ETA + route geometry
│   ├── Search/                  # Autocomplete, search, offline cache
│   ├── Notifications/           # Alarm notifications
│   ├── Network/                 # Reachability monitoring
│   └── AudioManager.swift       # Alarm playback, vibration, preview
└── Utilities/
    └── GeoJSONManager.swift     # GeoJSON decoder
```

---

## MVP Checklist

- [x] App compiles and runs on physical device
- [x] User can select destination on map
- [x] User can select and persist lead time (3 / 5 / custom minutes)
- [x] App calculates ETA or shows offline fallback
- [x] App detects online/offline status
- [x] App validates location permissions (Always required)
- [x] App registers region monitoring (geofence)
- [x] App fires local notification near destination
- [x] App can cancel trip and clean up GPS/notifications
- [x] Unit tests for trip logic (TripEngine, Geofence, TripMath, etc.)
- [x] UI tests for launch and basic flow

---

## User Acceptance Criteria (8 HUs)

| ID | User Action | Goal |
|---|---|---|
| HU01 | Drop a pin on the map as destination | App triggers alarm when entering geofence |
| HU02 | Cancel an active trip | Stops GPS, purges scheduled notifications |
| HU03 | Configure alert based on ETA | Wakes user with exact lead time before stop |
| HU04 | Update destination coordinates mid-trip | Recalculates geofence + ETA without restart |
| HU05 | Select lead time from preset options | Customizable alarm trigger time |
| HU06 | App remembers last selected lead time | Faster trip setup via UserDefaults persistence |
| HU07 | App warns if GPS not set to "Always" | Prevents background alarm failure |
| HU08 | Offline indicator shown when no internet | Confirms fallback algorithm is active |

---

## License

Internal project — not licensed for public distribution.
