# 🚌 Busnap: Smart Transit Alarm

**Busnap** is a native iOS application built in Swift that implements a dynamic geofencing and Adaptive Polling algorithm. Designed for commuters, it intelligently manages background GPS usage based on ETA calculations to drastically reduce battery consumption, ensuring high-priority, location-based wake-up alerts just before the destination is reached.

---

##  Key Features

* **Adaptive Polling Algorithm:** Dynamically adjusts the GPS hardware sleep cycle by halving the estimated travel time to drastically reduce battery drainage[cite: 1].
* **High-Priority Wake-Up:** Bypasses "Do Not Disturb" and Focus modes using Time-Sensitive local notifications[cite: 1].
* **Offline Fallback Engine:** Calculates a mathematical radius and activates backup timers if the network connection is lost during transit[cite: 2].
* **Zero Server Maintenance:** Operates 100% natively on the client-side using Apple's frameworks, ensuring maximum user privacy and zero recurring API costs[cite: 1].
* **Continuous Audio Loop:** Enqueues multiple custom 30-second `.wav` files to simulate a traditional, uninterrupted alarm clock[cite: 1].

---

##  Architecture & Tech Stack

| Framework | Core Component | Responsibility |
| :--- | :--- | :--- |
| **Swift & UI** | Presentation Layer | Minimalist map interface using `MKMapView` and gesture recognizers for destination selection[cite: 2]. |
| **CoreLocation** | Sensor Engine | Manages `Always Authorization` and `CLCircularRegion` to handle background geofencing[cite: 2]. |
| **MapKit** | Routing Engine | Queries transit-specific routes and ETA using `MKDirections` and `.transit` parameters[cite: 2]. |
| **UserNotifications** | Alert Subsystem | Schedules high-priority payloads and handles custom bundle sounds[cite: 2]. |
| **Network** | Connectivity | Evaluates online/offline states in real-time using `NWPathMonitor`[cite: 2]. |

---

##  How It Works 

1. **Target Selection:** The user drops a pin on the map to set the destination coordinates[cite: 2].
2. **ETA Calculation:** The system retrieves public transit data to estimate the arrival time[cite: 2].
3. **Smart Sleep Cycle:** If the estimated travel time is *T*, the algorithm puts the high-precision GPS sensor to sleep for *T/2*[cite: 1].
4. **Critical Threshold:** Upon entering a 3-minute or 1-km radius from the destination, continuous tracking is activated[cite: 1].
5. **Trigger & Cleanup:** The app fires the wake-up alarm, immediately shuts down GPS tracking to save power, and purges pending notification queues[cite: 1].

---

##  System Requirements

* **Platform:** iOS 15.0+[cite: 2]
* **Language:** Swift 5.0+[cite: 2]
* **Capabilities:** Background Modes (Location Updates)[cite: 2]
* **Privacy Strings:** `NSLocationAlwaysAndWhenInUseUsageDescription` is strictly required for the alarm to trigger while the device is locked[cite: 2].

---

##  Installation & Local Execution

1. Clone this repository: 
   `git clone https://github.com/YourUsername/Busnap.git`
2. Open `Busnap.xcodeproj` in Xcode.
3. Select your physical target device (Note: Background Location features and accurate geofencing require a physical iPhone, not the simulator).
4. Build and run using `Cmd + R`.

---

## 📄 License

**All Rights Reserved.**
This project is currently provided as a technical portfolio piece. Unauthorized commercial distribution or App Store publication is prohibited.
