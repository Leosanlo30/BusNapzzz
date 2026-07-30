# BusNap

**Native iOS public transit alighting alarm.** Parse GeoJSON bus networks, select a stop, and get an alarm when your bus approaches — all with adaptive GPS to save battery.

---

## Core Features

- **GeoJSON Parsing** — Loads OpenStreetMap bus-stop data (Point geometries with `name`, `ref`, `operator`) via a dedicated `GeoJSONManager`. Supports two formats: flat `PARADEROS_MERIDA` and route-linked `RUTAS_Merida`.
- **Adaptive Location Polling** — `AdaptiveLocationManager` dynamically switches Core Location accuracy based on distance to the target stop: `kCLLocationAccuracyThreeKilometers` (far), `kCLLocationAccuracyKilometer` (medium), `kCLLocationAccuracyBestForNavigation` (near). Background updates enabled with `allowsBackgroundLocationUpdates`.
- **Custom MapKit Annotations** — Lightweight `BusStopAnnotation` views rasterized via `.drawingGroup()` with spatial bounding-box filtering (`stopsInSight`) to cap visible views at ~50 stops.
- **Diacritic-Insensitive Search** — Stop and route search ignores accents and case via `String.folding(options: .diacriticInsensitive)`.
- **Proximity Alarm** — `TripEngine` + `GeofenceMonitor` trigger arrival at 1,000 m; dedicated 100 m trigger via `AdaptiveLocationManager` distance stream.
- **Theming Engine** — Liquid-glass `ultraThinMaterial` sheet themes with persistent selection via `UserDefaults`.

---

## Tech Stack

| Layer             | Technology |
|-------------------|------------|
| Language          | Swift 5.9+ |
| UI Framework      | SwiftUI (iOS 17+) |
| Architecture      | MVVM with `@Observable` |
| Maps              | MapKit (`MapCameraPosition`, `MapReader`, `Annotation`, `Marker`) |
| Location          | CoreLocation (`CLLocationManager`, `CLCircularRegion`) |
| Persistence       | `UserDefaults` / `@AppStorage` |
| GeoJSON           | `Codable` + custom `Decodable` models |
| Concurrency       | `async/await`, `Task`, `@MainActor` |
| Notifications     | `UNUserNotificationCenter` via `NotificationManager` |

---

## Setup & Installation

### Requirements

- Xcode 15.4+
- iOS 17.0+ (Deployment Target)
- Swift 5.9+
- CocoaPods / SPM **not required** — all dependencies are system frameworks.

### Steps

```bash
git clone https://github.com/Leosanlo30/BusNapzzz.git
cd BusNapzzz
open BusNap.xcodeproj
```

1. Select a simulator or a physical device running iOS 17+.
2. Build and run (`Cmd+R`).
3. Grant **Always** location permission when prompted — required for background alarms.
4. Pan/zoom the Mérida map to see bus stops appear at street-level zoom.
5. Tap a stop or type its name in the search sheet to set it as destination.
6. Press **Iniciar Viaje** to start monitoring. The GPS accuracy adapts automatically as you approach.

### GeoJSON Data

The app bundles three OpenStreetMap-derived GeoJSON files under `Resources/Navigation/`:

- `PARADEROS_MERIDA.geojson` — Primary stop list (name + ref + coordinates)
- `RUTAS_Merida.geojson` / `RUTAS_Merida_2.geojson` — Route-linked stops with `@relations`

Additional test route GPX files are in `TestRoutes/`.

---

## Project Structure

```
BusNap/
├── BusNapApp.swift              # App entry point
├── Core/
│   ├── TripEngine/              # Trip state machine + alarm dispatch
│   ├── Theme/                   # AppConstants, EnvironmentKeys
│   ├── Storage/                 # UserPreferencesStoring protocol + impl
│   └── UIComponents/            # Reusable SwiftUI views
├── Features/
│   └── MapDashboard/            # Main screen: ViewModel + Views
├── Models/                      # BusStop, Destination, TripState, etc.
├── Resources/                   # GeoJSON, audio alarms, assets
├── Services/
│   ├── Location/                # AdaptiveLocationManager, GeofenceMonitor, etc.
│   ├── Routing/                 # MapKit ETA estimation
│   ├── Notifications/           # Alarm scheduling
│   ├── Network/                 # Reachability monitoring
│   └── AudioManager.swift       # Alarm playback
└── Utilities/
    └── GeoJSONManager.swift     # GeoJSON decoder
```

---

## License

Internal project — not licensed for public distribution.
