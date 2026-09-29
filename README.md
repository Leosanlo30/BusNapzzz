# BusNap

**Native iOS public transit alighting alarm for Mérida bus stops.** Parse GeoJSON bus networks, select a stop, and get an alarm when your bus approaches — all with adaptive GPS to save battery.

---

## Purpose — What Exactly the Project Solves

**Busnapzzz** is a native iOS application designed for students (and daily commuters) in Mérida, Mexico who:

- Frequently forget which bus stop they need to get off at.
- Want to be alerted automatically when their bus is approaching, even while using other apps or with the screen locked.
- Need a battery-efficient solution that adapts GPS polling frequency based on distance to destination.

The app solves the real-world problem of **missing a bus stop due to distraction** by providing a smart geofence-based alarm system. Users drop a pin on their destination stop, and the app monitors their location in the background. When the user is within a configurable lead time/radius, the app fires a time-sensitive notification and plays an alarm sound — waking them up even if Do Not Disturb is active.

---

## Documentation: Clone Repo to Test

### Prerequisites

| Requirement | Version |
|---|---|
| macOS | Ventura 13.0+ (for Xcode) |
| Xcode | 15.4+ |
| iOS Simulator | iOS 17.0+ |
| Git | 2.30+ |

### Clone and Run

```bash
# Clone the repository
git clone https://github.com/Leosanlo30/BusNapzzz.git
cd BusNapzzz

# Switch to the rutas_Merida branch (Merida bus route data)
git checkout rutas_Merida

# Open in Xcode
open BusNap.xcodeproj
```

1. Select a simulator (iOS 17+) or connect a physical iOS device.
2. Build and run with `Cmd+R`.
3. Grant **Always** location permission when prompted — required for background alarms.
4. Pan/zoom the Mérida map to see bus stops appear at street-level zoom.
5. Tap a stop or type its name in the search sheet to set it as destination.
6. Press **Iniciar Viaje** to start monitoring. GPS accuracy adapts automatically as you approach.

### GeoJSON Data (Bundled)

The app includes pre-bundled OpenStreetMap-derived GeoJSON files for Mérida's bus network:

| File | Format | Description |
|---|---|---|
| `PARADEROS_MERIDA.geojson` | Flat stops | Primary stop list with `name`, `ref`, `operator` |
| `RUTAS_Merida.geojson` | Route-linked | Stops nested under `@relations` with route names |
| `RUTAS_Merida_2.geojson` | Route-linked | Alternative route file with `@relations` |

Additional test routes are in `BusNap/TestRoutes/` (`.gpx` files).

### Testing

```bash
# Unit tests (Swift Testing framework)
# In Xcode: Product → Test, or Cmd+U

# Test targets:
# BusNapTests — 14 test files covering models, trip engine, geofence, ViewModel, etc.
# BusNapUITests — Launch test and basic flow UI test
```

| Test File | What It Covers |
|---|---|
| `DestinationTests.swift` | Model equality, hashing, Codable |
| `TripMathTests.swift` | Sleep calculation, critical threshold logic |
| `TripEngineTests.swift` | State machine transitions |
| `GeofenceMonitorTests.swift` | Region entry/exit behavior |
| `MapDashboardViewModelTests.swift` | ViewModel state updates |
| `AdaptivePollingPolicyTests.swift` | Adaptive polling decisions |
| `TripConfigurationTests.swift` | Trip configuration validation |
| `AlarmStatusTests.swift` | Alarm state transitions |
| `AlertLeadTimeTests.swift` | Lead time selection logic |
| `BusNapUITests.swift` | App launch and basic navigation |

---

## Architecture Design

### Pattern: MVVM with `@Observable` (iOS 17+)

BusNap follows a strict **Model–View–ViewModel** architecture with SwiftUI's `@Observable` for reactive state binding. All service dependencies are injected via protocols, making the app fully testable with mocks.

```
┌──────────────────────────────────────────────────────────────┐
│  View Layer (SwiftUI)                                            │
│  MapDashboardView → DestinationMapView                          │
│  BottomSheetContent, SettingsView, LeadTimePickerView           │
│  Reads @Bindable var viewModel                                   │
└──────────────┬─────────────────────────────────────────────────┘
               │  observation / bindings
┌──────────────▼─────────────────────────────────────────────────┐
│  ViewModel Layer                                                   │
│  MapDashboardViewModel (@Observable)                              │
│  Owns: tripEngine, locationManager, networkMonitor              │
│  Publishes: busStops, stopsInSight, searchSuggestions           │
│            isApproachingStop, selectedDestination                │
└──────┬──────────────────────┬───────────────────────────────────┘
       │                      │
       ▼                      ▼
┌──────────────┐   ┌──────────────────────────┐
│ Services       │   │ Core Layer                  │
│ GeoJSON        │   │ TripEngine (state machine)│
│ Location       │   │ GeofenceMonitor           │
│ Routing/ETA    │   │ TripMath (pure logic)     │
│ Network        │   │ NotificationManager       │
│ AudioManager   │   │ AdaptivePollingPolicy     │
└──────────────┘   └──────────────────────────┘
```

### Layer Responsibilities

| Layer | Directory | Responsibility |
|---|---|---|
| **App Entry** | `BusNap/BusNapApp.swift` | `@main` SwiftUI app struct, scene phase handling, theme activation |
| **Models** | `BusNap/Models/` | Pure data types: `Destination`, `BusStop`, `TripState`, `AlarmStatus`, `TripConfiguration`, `PlaceResult`, `AlertLeadTime` |
| **Core** | `BusNap/Core/` | `TripEngine` (state machine), `TripMath` (pure math), `Theme` (styling), `Storage` (UserDefaults), `UIComponents` (reusable views) |
| **Features** | `BusNap/Features/` | `MapDashboard` (main screen ViewModel + Views), `Settings` (preferences) |
| **Services** | `BusNap/Services/` | `Location` (GPS), `Routing` (ETA via MapKit), `Network` (reachability), `Notifications` (alarms), `AudioManager` |
| **Utilities** | `BusNap/Utilities/` | `GeoJSONManager` — decodes OpenStreetMap GeoJSON into `BusStop` models |
| **Resources** | `BusNap/Resources/` | GeoJSON data files, audio alarm files (`.mp3`, `.caf`) |
| **TestRoutes** | `BusNap/TestRoutes/` | `.gpx` test route files for simulation |

### Key Design Rules

1. **ViewModels never import UIKit.** They operate purely on model types and CoreLocation/MapKit value types.
2. **All service dependencies are injected** via protocols with optional constructor parameters, defaulting to production implementations.
3. **Side effects (network, location, audio) are encapsulated behind protocols:**
   - `LocationManaging` → `AdaptiveLocationManager`
   - `RouteEstimating` → `MapKitRouteEstimator`
   - `NetworkMonitoring` → `NetworkMonitor`
   - `NotificationScheduling` → `NotificationManager`
   - `UserPreferencesStoring` → `UserDefaultsPreferencesStore`

### Core Data Flow

#### GeoJSON → BusStop Pipeline

```
GeoJSON file (bundle)
       │
       ▼
GeoJSONManager.loadParaderos(from:) / loadBusStops(from:)
       │  Decodes FeatureCollection → ParaderoFeature[] / RouteFeature[]
       │  Maps each to BusStop { id, name, coordinate, routeNames }
       ▼
MapDashboardViewModel.busStops
       │
       ├── filteredBusStops  (searchText + route filter)
       ├── stopsInSight      (spatial bounding-box filter, max 50)
       └── searchSuggestions (merges routes + stops + favorites)
```

#### Adaptive Location Polling

```
CLLocationManager.didUpdateLocations
       │
       ▼
AdaptiveLocationManager.reevaluateAccuracy(for:)
       │  Distance to destination determines accuracy level:
       │  • > 3000 m → kCLLocationAccuracyThreeKilometers
       │  • > 2000 m → kCLLocationAccuracyKilometer
       │  • ≤ 1000 m → kCLLocationAccuracyBestForNavigation
       ▼
locationHandler → MapDashboardViewModel.processLocationUpdate
       │
       ├── isApproachingStop = (distance < 500 m)
       ├── At 100 m: tripEngine.triggerArrival(for:)
       └── Background: enableEcoMode() drops to 3 km accuracy
```

#### Trip State Machine

```
              ┌─────────┐
              │  idle   │
              └────┬────┘
                   │ select stop
                   ▼
            ┌────────────┐
            │ configured │
            └──────┬─────┘
                   │ startTrip()
                   ▼
            ┌────────────┐
       ┌───│ monitoring  │◄──────────┐
       │   └──────┬─────┘            │
       │          │ Geofence enter    │ resumeTrip()
       │          ▼    or 100 m       │
       │   ┌────────────┐            │
       │   │criticalZone│            │
       │   └──────┬─────┘            │
       │          │ alarm fires       │
       │          ▼                  │
       │   ┌────────────┐            │
       │   │alarmTrigger│            │
       │   └────────────┘            │
       │          │                  │
       │          ▼                  │
       │      (user stops)           │
       │          │                  │
       └──────────┘  cancelTrip()    │
                                     │
       cancelTrip() ───────────────┘
```

### Adaptive Polling Algorithm

```
User drops pin → GPS coordinates captured
       │
       ▼
NWPathMonitor checks connectivity
       │
       ├── ONLINE  → MKDirections calculates ETA → geofence registered
       └── OFFLINE → Math radius from avg speed → exact geofence + backup timer
       │
       ▼
Compute sleep = ETA ÷ 2 (TripMath.calculateInitialSleep)
       │
       ▼
GPS sleeps for T/2 → Wake up → re-evaluate position
       │
       ▼
Is device within critical threshold? (< 3 min OR < 1 km)
       │
       ├── NO  → Recalculate ETA → loop back to sleep
       └── YES → Exit polling → activate continuous tracking → geofence entry → fire alarm
```

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
| Notifications     | `UNUserNotificationCenter` |
| GeoJSON           | `Codable` + custom `Decodable` models |
| Concurrency       | `async/await`, `Task`, `@MainActor` |
| Routing/ETA       | `MKDirections` (MapKit) |
| Audio             | AVFoundation (`.mp3`, `.caf` alarm files) |
| Networking        | `NWPathMonitor` (Network framework) |

---

## Project Structure

```
BusNapzzz/
├── BusNap/                              # Main app target
│   ├── BusNapApp.swift                  # @main entry point
│   ├── Info.plist                       # Background modes: location + audio
│   ├── Assets.xcassets/                 # App icons, colors
│   ├── Core/                            # Cross-cutting concerns
│   │   ├── TripEngine/                  # Trip state machine + alarm dispatch
│   │   │   ├── TripEngine.swift
│   │   │   ├── TripState.swift
│   │   │   └── AdaptivePollingPolicy.swift
│   │   ├── Theme/                       # Styling engine
│   │   │   ├── AppConstants.swift
│   │   │   ├── AppThemeModifier.swift
│   │   │   ├── LiquidGlassModifiers.swift
│   │   │   └── ThemeManager.swift
│   │   ├── Storage/                     # Persistence
│   │   │   ├── UserPreferencesStoring.swift
│   │   │   └── UserDefaultsPreferencesStore.swift
│   │   └── UIComponents/                # Reusable SwiftUI views
│   │       ├── PrimaryButton.swift
│   │       ├── HapticButtonStyle.swift
│   │       └── TripUIState.swift
│   ├── Features/                        # Feature modules
│   │   └── MapDashboard/
│   │       ├── MapDashboardViewModel.swift
│   │       └── Views/
│   │           ├── MapDashboardView.swift
│   │           ├── Components/
│   │           │   ├── BottomSheetContent.swift
│   │           │   ├── DestinationMapView.swift
│   │           │   ├── LeadTimePickerView.swift
│   │           └── ...
│   ├── Models/                          # Pure data types
│   │   ├── Destination.swift
│   │   ├── BusStop.swift
│   │   ├── TripState.swift
│   │   ├── AlarmStatus.swift
│   │   ├── TripConfiguration.swift
│   │   ├── PlaceResult.swift
│   │   └── AlertLeadTime.swift
│   ├── Services/                        # External integrations
│   │   ├── Location/
│   │   │   ├── LocationManager.swift
│   │   │   ├── AdaptiveLocationManager.swift
│   │   │   ├── GeofenceMonitor.swift
│   │   │   ├── LocationManaging.swift
│   │   │   └── LocationPermissionState.swift
│   │   ├── Routing/
│   │   │   ├── MapKitRouteEstimator.swift
│   │   │   ├── RouteEstimating.swift
│   │   │   └── RouteEstimate.swift
│   │   ├── Network/
│   │   │   ├── NetworkMonitor.swift
│   │   │   └── NetworkMonitoring.swift
│   │   ├── Notifications/
│   │   │   ├── NotificationManager.swift
│   │   │   └── NotificationScheduling.swift
│   │   └── AudioManager.swift
│   ├── Utilities/
│   │   └── GeoJSONManager.swift
│   ├── Docs/
│   │   └── UI-Component-Map.md
│   └── Resources/
│       ├── Navigation/
│       │   ├── PARADEROS_MERIDA.geojson
│       │   ├── RUTAS_Merida.geojson
│       │   └── RUTAS_Merida_2.geojson
│       └── Sounds/
│           ├── alarm.mp3, alarm2.mp3, alarm3.mp3, busnap_alarm.caf
├── BusNapTests/                         # Unit tests (Swift Testing)
│   ├── Mocks/
│   └── *.swift                          # 14 test files
├── BusNapUITests/                       # UI tests
├── TestRoutes/                          # .gpx test route files
├── BusNap.xcodeproj/                    # Xcode project
├── README.md                            # This file
├── ARCHITECTURE.md                      # Detailed architecture reference
├── flowchart_trip_config.md             # Trip initialization flowchart (Mermaid)
├── Documentation/                       # Additional docs
│   ├── Arquitecture/MVVM_proposal.md
│   ├── Design/design.md
│   ├── Destination.md
│   ├── HU_Interface_Trip_Config.md      # User acceptance criteria (8 HUs)
│   ├── MVP.md                           # Minimum viable product checklist
│   └── TripMath.md                      # Core math module documentation
└── BusNapTests/                         # Test target
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
