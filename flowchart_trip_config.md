# BusNap — Trip Initialization & Adaptive Polling Flowchart

```mermaid
flowchart TD
    A([USER OPENS APP]) --> B[User long-presses map\nto drop a pin on destination]
    B --> C[App captures GPS coordinates\nfrom pin location]
    C --> D{Internet connection\navailable?\nNWPathMonitor}

    %% --- ONLINE PATH ---
    D -- YES\nOnline --> E[Use Apple MapKit API\nto calculate ETA via transit route]
    E --> F[Register approach geofence\nCLCircularRegion — approx. radius]

    %% --- OFFLINE PATH ---
    D -- NO\nOffline --> G[Calculate mathematical radius\nbased on average transport speed]
    G --> H[Register exact geofence\nCLCircularRegion — precise radius]
    H --> I[Activate time-based\nbackup timer\nin case of GPS signal loss]

    %% --- CONVERGE ---
    F --> J[Compute Smart Sleep Cycle\nSleep = ETA ÷ 2]
    I --> J

    J --> K[Put high-precision GPS sensor\nto sleep for T/2 duration\nAdaptive Polling Algorithm]

    %% --- EVALUATION LOOP ---
    K --> L{Is device within\nCritical Threshold?\n< 3 minutes OR < 1 km\nfrom destination}

    L -- NO\nThreshold Not Met --> M[Evaluate edge cases &\noptimize sensor usage]
    M --> N[Recalculate ETA &\nadjust sleep cycle]
    N --> K

    %% --- CRITICAL ZONE ---
    L -- YES\nThreshold Met --> O[Exit Adaptive Polling cycle]
    O --> P[Activate high-fidelity\ncontinuous tracking\nCoreLocation always-on]
    P --> Q{Device entered\ngeofence region?}

    Q -- NO --> P

    Q -- YES --> R[Fire Time-Sensitive\nWake-Up Alarm\nUserNotifications — bypasses DND]
    R --> S[Play continuous audio loop\n30-sec .wav files enqueued]
    S --> T[Stop GPS tracking\nPurge pending notifications\nFree battery resources]
    T --> U([TRIP COMPLETE])
```

---

## Flow Summary

### Phase 1 — Trip Initialization & Configuration
| Step | Action | Framework |
|------|--------|-----------|
| 1 | User drops a pin on the map | `MKMapView` |
| 2 | App captures GPS coordinates | `CoreLocation` |
| 3 | System checks internet connectivity | `NWPathMonitor` |
| 3a (Online) | Apple API calculates ETA → approach geofence registered | `MKDirections` / `CLCircularRegion` |
| 3b (Offline) | Math radius from avg. speed → exact geofence + backup timer | `CLCircularRegion` / Timer |

### Phase 2 — Adaptive Polling (Smart Sleep Cycle)
| Step | Action |
|------|--------|
| 4 | Compute sleep duration = ETA ÷ 2 |
| 5 | GPS sensor sleeps for T/2 (drastically reduces battery drain) |
| 6 | Wake up and re-evaluate position |

### Phase 3 — Evaluation Loop (Critical Threshold)
| Step | Action |
|------|--------|
| 7 | Check if device is within < 3 min or < 1 km from destination |
| 7a (Not met) | Evaluate edge cases → recalculate ETA → loop back to sleep |
| 7b (Met) | Exit optimization → activate high-fidelity continuous tracking |

### Phase 4 — Trigger & Cleanup
| Step | Action | Framework |
|------|--------|-----------|
| 8 | Geofence entry detected | `CLCircularRegion` |
| 9 | Fire Time-Sensitive alarm (bypasses DND / Focus modes) | `UserNotifications` |
| 10 | Play continuous `.wav` audio loop | AVFoundation |
| 11 | Stop GPS, purge notifications, free battery | `CoreLocation` / `UserNotifications` |
```
