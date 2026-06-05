# AirPostureCore

Reusable AirPods head-tracking and posture scoring for iOS and macOS apps.

## Scope

This package intentionally contains only core tracking logic:

- `CMHeadphoneMotionManager` wrapping through `HeadphoneMotionProvider`
- posture sample validation and degree conversion
- low-pass pitch smoothing
- adjusted-pitch posture classification
- pitch history
- session timing and good-posture score
- calibration state and threshold calculation

The host app owns UI, avatars, persistence, haptics, notifications, Live Activities, audio route pickers, and background execution.

## Basic Consumer Usage

```swift
import AirPostureCore
import Combine

@MainActor
final class NotchPostureModel: ObservableObject {
    @Published private(set) var snapshot = AirPostureSnapshot.initial

    private let tracker = AirPostureTracker()
    private var cancellable: AnyCancellable?

    init() {
        cancellable = tracker.$snapshot.assign(to: \.snapshot, on: self)
    }

    func start() {
        tracker.startMotionUpdates()
        tracker.startSession()
    }

    func stop() -> AirPostureSessionSummary? {
        let summary = tracker.endSession()
        tracker.stopMotionUpdates()
        return summary
    }
}
```

Render `snapshot.adjustedPitchDegrees`, `snapshot.quality`, `snapshot.goodPosturePercent`, and `snapshot.connectionState` in the host app's notch/menu UI.

---

## macOS Integration (Notch / Menu Bar Apps)

AirPostureCore supports **macOS 14.0 (Sonoma) and later** via `CMHeadphoneMotionManager`, which Apple expanded to macOS at WWDC23.

### 1. Info.plist Configuration

Add the motion usage description so macOS can prompt the user:

```xml
<key>NSMotionUsageDescription</key>
<string>AirPosture needs access to your AirPods motion sensors to track your head posture.</string>
```

If your app also uses Bluetooth directly (e.g. for device discovery), add:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>AirPosture uses Bluetooth to connect to your AirPods for posture tracking.</string>
```

### 2. Sandbox Entitlements

If your app is sandboxed (recommended for App Store), enable the required entitlements:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.bluetooth</key>
<true/>
```

Motion data access requires user authorization — macOS will show a system permission dialog on first use.

### 3. Menu Bar / Notch Usage Pattern

Most notch apps use `MenuBarExtra` (SwiftUI) or a custom `NSPanel` positioned at the notch. Here's how to wire up AirPostureCore:

```swift
import SwiftUI
import AirPostureCore
import Combine

@main
struct NotchPostureApp: App {
    @StateObject private var model = NotchPostureModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                // Connection status
                Label(
                    model.snapshot.connectionState == .connected
                        ? "Connected" : "Disconnected",
                    systemImage: model.snapshot.connectionState == .connected
                        ? "headphones" : "headphones.circle"
                )

                Divider()

                // Current posture angle
                Text("Pitch: \(String(format: "%.1f", model.snapshot.adjustedPitchDegrees))°")

                // Posture quality indicator
                HStack {
                    Circle()
                        .fill(model.snapshot.quality == .good ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(model.snapshot.quality == .good ? "Good posture" : "Slouching")
                }

                // Session score
                if model.snapshot.sessionSnapshot != nil {
                    Divider()
                    Text("Score: \(Int(model.snapshot.goodPosturePercent))%")
                }

                Divider()

                Button(model.isTracking ? "Stop" : "Start") {
                    if model.isTracking {
                        model.stop()
                    } else {
                        model.start()
                    }
                }
            }
        } label: {
            Image(systemName: model.snapshot.quality == .good
                ? "checkmark.circle.fill"
                : "exclamationmark.circle.fill")
        }
    }
}

@MainActor
final class NotchPostureModel: ObservableObject {
    @Published private(set) var snapshot = AirPostureSnapshot.initial
    private(set) var isTracking = false

    private let tracker = AirPostureTracker()
    private var cancellable: AnyCancellable?

    init() {
        cancellable = tracker.$snapshot.assign(to: \.$snapshot, on: self)
    }

    func start() {
        tracker.startMotionUpdates()
        tracker.startSession()
        isTracking = true
    }

    func stop() -> AirPostureSessionSummary? {
        let summary = tracker.endSession()
        tracker.stopMotionUpdates()
        isTracking = false
        return summary
    }
}
```

### 4. Custom NSWindow / NSPanel (AppKit)

If you prefer a custom window positioned at the notch (e.g. for a floating HUD):

```swift
import AirPostureCore

@MainActor
final class PostureWindowController: NSWindowController {
    private let tracker = AirPostureTracker()
    private var cancellable: AnyCancellable?

    override func windowDidLoad() {
        super.windowDidLoad()
        cancellable = tracker.$snapshot.sink { [weak self] snapshot in
            guard let self else { return }
            self.postureLabel.stringValue = String(format: "%.1f°", snapshot.adjustedPitchDegrees)
            self.statusDot.fillColor = snapshot.quality == .good ? .systemGreen : .systemRed
        }
        tracker.startMotionUpdates()
        tracker.startSession()
    }

    deinit {
        // Note: in production, call endSession/stopMotionUpdates
        // before the controller is deallocated (e.g. in windowWillClose).
        // deinit runs on a non-isolated context, so MainActor-isolated
        // cleanup should happen earlier.
    }
}
```

### 5. SensorLocation (Left vs Right Earbud)

On macOS, `CMHeadphoneMotionManager` vends a `sensorLocation` property indicating which earbud is streaming data. The current `HeadphoneMotionAttitudeSample` does not include this field. If your app needs to differentiate between left and right earbuds (e.g. for asymmetric posture detection), you can access it through the delegate pattern:

```swift
// Extend CMHeadphoneMotionProvider to expose sensorLocation
extension CMHeadphoneMotionManager {
    var currentSensorLocation: CMSensorDataLocation {
        return sensorLocation
    }
}
```

> **Note:** Data is vended from one earbud at a time. The framework handles switching automatically, but if your UI needs to reflect which earbud is active, you'll need to poll `sensorLocation` or observe it via `CMHeadphoneMotionManagerDelegate`.

### 6. macOS Limitations

| Limitation | Details |
|---|---|
| **Minimum OS** | macOS 14.0 (Sonoma) required for `CMHeadphoneMotionManager` |
| **Hardware required** | User must wear AirPods Pro (any gen), AirPods (3rd gen+), AirPods Max, or compatible Beats with spatial audio + dynamic head tracking |
| **Simulator** | No headphone motion data in Simulator — use `MockHeadphoneMotionProvider` for UI development |
| **Background** | macOS apps do not have the same background execution model as iOS. Motion updates stop when the app is not in the foreground unless you use background audio tricks |
| **Single earbud** | Data comes from one earbud at a time; the framework auto-switches |
| **Authorization** | macOS will prompt for motion permission on first use. If denied, `isDeviceMotionAvailable` returns `false` |

### 7. Integration Checklist

- [ ] Add `AirPostureCore` as a Swift Package dependency (git URL or local path)
- [ ] Add `NSMotionUsageDescription` to `Info.plist`
- [ ] Add `com.apple.security.device.bluetooth` entitlement if sandboxed
- [ ] Create `AirPostureTracker` instance (retain it for the app's lifetime)
- [ ] Subscribe to `tracker.$snapshot` via Combine
- [ ] Call `startMotionUpdates()` when the user initiates tracking
- [ ] Call `stopMotionUpdates()` when the app terminates or the user stops
- [ ] Handle `connectionState` changes (`.connecting`, `.connected`, `.reconnecting`, `.disconnected`, `.error`)
- [ ] Test with real AirPods — Simulator won't have motion data
