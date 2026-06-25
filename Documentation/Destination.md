# Destination Model

## Overview

`Destination` is a pure domain model that represents a geographic point the user selects on the map. It lives in the `Models/` layer of the MVVM architecture, meaning it has **no UI, no GPS, and no external framework dependencies** — it only describes data.

---

## File location

```
BusNap/
└── Models/
    └── Destination.swift
```

---

## Full source

```swift
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
```

---

## Design decisions

### `struct` instead of `class`

`Destination` is a value type. Every time it is passed to a function or assigned to a variable, Swift creates an independent copy. This makes it:

- **Thread-safe** — no shared mutable state
- **Predictable** — changes in one place never silently affect another

### Properties

| Property | Type | Required | Description |
|---|---|---|---|
| `name` | `String?` | No | Human-readable label for the destination. Optional because a pin dropped on the map has no name until the user provides one. |
| `latitude` | `Double` | Yes | Geographic latitude in decimal degrees (e.g. `19.4326`). |
| `longitude` | `Double` | Yes | Geographic longitude in decimal degrees (e.g. `-99.1332`). |

### Initializer

```swift
init(name: String? = nil, latitude: Double, longitude: Double)
```

`name` defaults to `nil` so callers only need to provide coordinates:

```swift
// Pin dropped on map — no name yet
let pinned = Destination(latitude: 19.4326, longitude: -99.1332)

// User named their destination
let named = Destination(name: "Home", latitude: 19.4326, longitude: -99.1332)
```

### Protocol conformances

| Protocol | Why |
|---|---|
| `Equatable` | Allows `==` comparisons between two destinations. Used in logic (did the user move the pin?) and in tests. |
| `Hashable` | Allows `Destination` to be stored in a `Set` or used as a `Dictionary` key. Enables future features like a favorites list. |
| `Codable` | Automatic JSON encode/decode with no extra code. Ready for `UserDefaults` persistence (saves the last used destination between sessions). |

All three conformances are **synthesized automatically** by the Swift compiler because every property already conforms to those protocols.

---

## Tests

### File location

```
BusNapTests/
└── DestinationTests.swift
```

### What each test verifies

```swift
@Suite("Destination")
struct DestinationTests {
```

| Test | What it checks |
|---|---|
| `nameIsNilByDefault()` | When no name is passed, `name` is `nil` |
| `storesProvidedName()` | When a name is passed, it is stored correctly |
| `storesLatitudeAndLongitude()` | Coordinates are stored exactly as provided |
| `equalWhenCoordinatesAndNameMatch()` | Two destinations with identical data are equal (`==`) |
| `notEqualWhenCoordinatesDiffer()` | Two destinations with different coordinates are not equal (`!=`) |

### Relationship between model and tests

```
Destination.swift  ──────────────────────────────────────────────────────┐
  struct Destination                                                       │
    - name: String?           ←── nameIsNilByDefault()                   │
                              ←── storesProvidedName()                   │
    - latitude: Double        ←── storesLatitudeAndLongitude()           │
    - longitude: Double       ←── storesLatitudeAndLongitude()           │
    - Equatable               ←── equalWhenCoordinatesAndNameMatch()     │
                              ←── notEqualWhenCoordinatesDiffer()        │
                                                                          │
DestinationTests.swift  ─────────────────────────────────────────────────┘
```

Each test targets one specific contract of the model. If a property or conformance is ever accidentally removed or broken, exactly one test fails, pointing directly to the regression.

### Test results

```
✔ nameIsNilByDefault         passed in 0.001s
✔ storesProvidedName         passed in 0.001s
✔ storesLatitudeAndLongitude passed in 0.001s
✔ equalWhenCoordinatesAndNameMatch passed in 0.001s
✔ notEqualWhenCoordinatesDiffer   passed in 0.001s

Suite "Destination" passed — 5 tests in 0.001 seconds
```

---

## Where this fits in MVVM

```
Models/           ← Destination lives here (pure data, no dependencies)
   └── Destination.swift

Services/         ← Will convert Destination → CLLocationCoordinate2D for GPS
Features/         ← ViewModel reads Destination and passes it to LocationManager
```

`Destination` is intentionally kept dependency-free. The conversion to CoreLocation types (`CLLocationCoordinate2D`) happens at the `Services` layer, keeping this model fast to test and easy to reuse.
