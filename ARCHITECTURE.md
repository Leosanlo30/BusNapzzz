# BusNap — Architecture

## MVVM Implementation

BusNap follows a strict **Model–View–ViewModel** pattern with `@Observable` (iOS 17) for reactive state binding.

```
┌──────────────────────────────────────────────────────┐
│  View Layer (SwiftUI)                                 │
│  MapDashboardView → DestinationMapView               │
│  BottomSheetContent, SettingsView                     │
│  Reads @Bindable var viewModel                        │
└──────────────┬───────────────────────────────────────┘
               │  observation / bindings
┌──────────────▼───────────────────────────────────────┐
│  ViewModel Layer                                      │
│  MapDashboardViewModel (@Observable)                  │
│  Owns: tripEngine, locationManager, networkMonitor    │
│  Publishes: busStops, stopsInSight, searchSuggestions │
│            isApproachingStop, selectedDestination      │
└──────┬──────────────────────┬────────────────────────┘
       │                      │
       ▼                      ▼
┌──────────────┐   ┌──────────────────────────┐
│ Services     │   │ Core Layer                │
│ GeoJSON      │   │ TripEngine (state machine)│
│ Location     │   │ GeofenceMonitor           │
│ Routing/ETA  │   │ NotificationManager       │
│ Network      │   │                           │
└──────────────┘   └──────────────────────────┘
```

### Key Design Rules

1. **ViewModels never import UIKit.** They operate purely on model types and `CoreLocation` / `MapKit` value types.
2. **All service dependencies are injected** via optional constructor parameters, defaulting to production implementations. This makes previews and unit tests trivial.
3. **Side effects (network, location, audio) are encapsulated behind protocols** (`LocationManaging`, `RouteEstimating`, `NetworkMonitoring`, `NotificationScheduling`).

---

## Core Service Interactions

### 1. GeoJSON → BusStop Pipeline

```
GeoJSON file (bundle)
       │
       ▼
GeoJSONManager.loadParaderos(from:)
       │  Decodes FeatureCollection → ParaderoFeature[]
       │  Maps each to BusStop { id, name, coordinate, routeNames }
       ▼
MapDashboardViewModel.busStops
       │
       ├── filteredBusStops  (applies searchText + route filter)
       ├── stopsInSight      (applies MKCoordinateRegion bounding-box)
       └── searchSuggestions (merges routes + stops + favorites)
```

The `GeoJSONManager` is a `static let shared` singleton. It exposes two parsers:
- `loadParaderos(from:)` — Handles the flat `PARADEROS_MERIDA.geojson` format with `name`, `ref`, `operator`, `public_transport` fields.
- `loadBusStops(from:)` — Handles the nested `RUTAS_Merida.geojson` format with `@relations` containing route names.

Both use private, file-scoped `Decodable` structs (`ParaderoCollection`, `FeatureCollection`, etc.) that are never exposed outside the manager.

### 2. AdaptiveLocationManager

```
AdaptiveLocationManager implements LocationManaging
       │
       ├── setDestination(CLLocationCoordinate2D)
       │       Sets the target CLLocation
       │
       ├── CLLocationManagerDelegate.didUpdateLocations
       │       Calculates distance → destination
       │       Calls reevaluateAccuracy(for:)
       │       Forwards location to handler
       │
       └── reevaluateAccuracy(for:)
               ├── distance > 3000 m  → .far    (3 km accuracy, 500 m filter)
               ├── distance > 2000 m  → .medium (1 km accuracy, 200 m filter)
               └── distance ≤ 1000 m  → .near   (BestForNavigation, 10 m filter)
               Only switches when crossing a threshold — no thrashing.
```

The manager exposes `distanceToDestination` as an observable property. The ViewModel reads it in `processLocationUpdate` to update `isApproachingStop` (true at < 500 m) and trigger `tripEngine.triggerArrival` at < 100 m.

**Eco Mode:** `enableEcoMode()` drops to 3 km accuracy when the app is backgrounded. `disableEcoMode()` re-evaluates based on current distance.

### 3. TripEngine State Machine

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
                    cancelTrip() ───────────┘
```

Transitions are driven by:
- **GeofenceMonitor** — `CLCircularRegion` at lead-time radius (≈ 1,000 m). Calls `onRegionEntered`.
- **AdaptiveLocationManager** — 100 m hard threshold in `processLocationUpdate` calls `tripEngine.triggerArrival`.

Both converge on the same `handleCriticalZoneEntry` method, which fires the audio alarm and schedules a `UNNotificationRequest`.

### 4. Map Annotation Rendering

```
MapDashboardViewModel.stopsInSight
       │  Spatial filter: MKCoordinateRegion bounds, max 50 stops
       ▼
ForEach(stopsInSight, id: \.id) { stop in
    Annotation(stop.name, coordinate: stop.coordinate) {
        VStack {
            BusStopAnnotation(isSelected: stop.id == selectedStop?.id)
            if isSelected { StopCallout(name: stop.name) }
        }
    }
    .annotationTitles(.hidden)
}
```

Performance triad:
- **Spatial filtering** — `stopsInSight` discards stops outside the visible `MKCoordinateRegion` bounds when count exceeds 50.
- **View rasterization** — `.drawingGroup()` on `BusStopAnnotation` flattens the composite to a Metal texture.
- **Camera debouncing** — `onMapCameraChange(frequency: .onEnd)` defers all region recomputation until the gesture ends.

The selected stop renders a `StopCallout` pill (ultra-thin material, bus icon + name). All other markers show only the compact circle-bus icon.

---

## Data Flow

### Stop Selection → Destination Set

```
User taps stop on map
       │
       ▼
DestinationMapView.onTapGesture
       │  Find nearest stop within 50 m
       ▼
viewModel.handleMapStopSelection(stop)
       │
       ├── selectedStop = stop
       ├── Destination(name: stop.name, lat, lng)
       └── updateDestination(dest)
               │
               ├── tripEngine.updateDestination(dest)
               ├── ETA fetch via RouteEstimating
               └── locationManager.setDestination(coord)
                       │
                       └── AdaptiveLocationManager now knows target
```

### Location Update → State Change

```
CLLocationManager.didUpdateLocations
       │  (background or foreground)
       ▼
AdaptiveLocationManager.reevaluateAccuracy(for:)
       │  Adjusts desiredAccuracy + distanceFilter
       │  Sets distanceToDestination
       ▼
locationHandler → MapDashboardViewModel.processLocationUpdate
       │
       ├── distanceToStop = locationManager.distanceToDestination
       ├── isApproachingStop = (distance < 500 m)
       ├── At 100 m: tripEngine.triggerArrival(for:)
       └── Every 60 s: fetchETA(for:) if monitoring
```

---

## State Management

All mutable state lives in `@Observable` classes. SwiftUI views observe changes automatically via `@Bindable`.

| Scope | Class | Key State |
|-------|-------|-----------|
| App-wide | `MapDashboardViewModel` | `busStops`, `selectedDestination`, `searchText`, `isApproachingStop`, `tripUIState` |
| Trip lifecycle | `TripEngine` | `state` (idle → configured → monitoring → criticalZone → alarmTriggered) |
| Location | `AdaptiveLocationManager` | `permissionState`, `currentAccuracy`, `distanceToDestination` |
| Persisted | `UserPreferencesStoring` | Theme, lead time, favorites, ringtone |

**Threading:** All state mutations happen on `@MainActor`. `CLLocationManagerDelegate` callbacks arrive nonisolated and are bridged via `Task { @MainActor in ... }`.

**Observation:**
- `@ObservationIgnored` on service references prevents redundant observation of transitive state.
- `@AppStorage` for simple user defaults (theme, vibration toggle) keeps the ViewModel from manually loading/saving.

---

## Dependencies & Protocols

| Protocol | Production Implementation | Purpose |
|----------|--------------------------|---------|
| `LocationManaging` | `AdaptiveLocationManager` | GPS + adaptive accuracy |
| `RouteEstimating` | `MapKitRouteEstimator` | ETA via `MKDirections` |
| `NetworkMonitoring` | `NetworkMonitor` | Reachability via `NWPathMonitor` |
| `NotificationScheduling` | `NotificationManager` | `UNUserNotificationCenter` wrapper |
| `UserPreferencesStoring` | `UserDefaultsPreferencesStore` | Theme, lead time, favorites |

Each protocol is small (1–3 methods) and injected in the ViewModel `init` with a default production value. This allows swapping any service for tests or SwiftUI previews by passing a mock.
