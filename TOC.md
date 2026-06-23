# Table of Contents

- [Overview](README.md#overview)
- [Prerequisites](README.md#prerequisites)
- [Quick Start](README.md#quick-start)
- [Firebase Configuration](README.md#firebase-configuration)
- [APNs & Live Activity Relay (Optional)](README.md#apns--live-activity-relay-optional)
- [Build Settings & Environment](README.md#build-settings--environment)
- [Project Structure](README.md#project-structure)
- [Running the App](README.md#running-the-app)
- [AirPostureCore Package](README.md#airposturecore-package)
- [License](README.md#license)


---

## Overview

AirPosture uses **ARKit body tracking** (iPhone's front-facing camera) and **AirPods headphone motion sensors** to monitor your posture in real time. It provides:

- 🧍 **Real-time posture detection** via ARKit body pose processing
- 🎧 **AirPods head tracking** via `CMHeadphoneMotionManager`
- 🔔 **Live Activities** and **Dynamic Island** support for at-a-glance status
- 🌙 **Background monitoring** with an APNs relay server for push-based Live Activity updates
- 🧘 **Stretch reminders** and session history tracking
- 📊 **Session scoring** and trend analytics

---

## Prerequisites

Before building the project, you'll need:

| Requirement | Details |
|---|---|
| **Xcode** | 16.0 or later (recommended) |
| **iOS** | Deployment target: 18.0 |
| **Apple Developer account** | Free account works for running on device; paid account needed for push notifications and Live Activities |
| **AirPods** | AirPods Pro (any gen), AirPods (3rd gen+), AirPods Max, or compatible Beats with spatial audio + dynamic head tracking |
| **iPhone** | iPhone XS or later (for ARKit body tracking) or any iPhone with iOS 18.0+ (AirPods-only mode) |
| **Node.js** (optional) | 20.x or later if deploying the Live Activity relay server |
| **XcodeGen** (optional) | Only needed if you modify `project.yml` and need to regenerate the `.xcodeproj` |

> **Note:** ARKit body tracking requires the iPhone's front-facing TrueDepth camera (iPhone XS and later). AirPods-only posture tracking works on any iPhone with iOS 18.0+.

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/your-username/AirPosture.git
cd AirPosture

# 2. Set up Firebase (see Firebase Configuration below)
#    - Create a Firebase project
#    - Download GoogleService-Info.plist
#    - Place it at AirPostureApp/GoogleService-Info.plist

# 3. Open the project in Xcode
open AirPosture.xcodeproj

# 4. Select your development team in Signing & Capabilities
# 5. Build and run on a physical device (ARKit and AirPods features 
#    won't work in the Simulator)
```

---

## Firebase Configuration

AirPosture uses **Firebase Analytics** for session tracking and usage insights.

### 1. Create a Firebase project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** and follow the setup wizard
3. Once created, click the **iOS** icon to add an iOS app to your project

### 2. Register your iOS app

1. Enter your bundle identifier (default: `com.example.airposture` — change to your own)
2. Download the `GoogleService-Info.plist` file

### 3. Add the config file to the project

Place the downloaded file at:

```
AirPostureApp/GoogleService-Info.plist
```

A template file is provided at `AirPostureApp/GoogleService-Info.plist.example` showing the expected format. **Do not commit the real `GoogleService-Info.plist`** — it is already ignored by `.gitignore`.

> **Note:** If you don't configure Firebase, the app will still build and run. Analytics calls will be no-ops. The Firebase dependency is a Swift Package managed through the `.xcodeproj` — SPM will resolve it automatically on first build.

---

## APNs & Live Activity Relay (Optional)

Live Activities with push updates require an **APNs relay server** to forward state updates from the app to Apple's Push Notification service. This is optional — without it, Live Activities will still work in **local/token mode** (updates sent directly from the app), but they won't receive push-based updates when the app is in the background.

### Relay Server Setup

The relay server is located in `live-activity-relay/`. See its [dedicated README](live-activity-relay/README.md) for full instructions.

**Quick setup:**

```bash
cd live-activity-relay
cp .env.example .env   # Create .env file (if .env.example exists)
```

**Required environment variables:**

| Variable | Description | How to get it |
|---|---|---|
| `APNS_TEAM_ID` | Your Apple Developer Team ID | [Apple Developer Portal](https://developer.apple.com/account) → Membership → Team ID |
| `APNS_KEY_ID` | APNs Auth Key ID | [Apple Developer Portal](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Keys → Create a new key with "Apple Push Notifications service (APNs)" enabled |
| `APNS_PRIVATE_KEY` or `APNS_PRIVATE_KEY_PATH` | `.p8` private key file | Downloaded when you create the APNs key above (only available once — save it securely) |
| `APP_BUNDLE_ID` | Your app's bundle identifier | e.g. `com.example.airposture` |
| `RELAY_API_KEY` | Shared secret (recommended) | Any random string you generate (e.g. `openssl rand -hex 32`) |

### Build Settings for the Relay

In Xcode (or via `project.yml`), set:

| Build Setting | Value |
|---|---|
| `LIVE_ACTIVITY_RELAY_BASE_URL` | Your relay server URL (e.g. `https://relay.yourdomain.com`) |
| `LIVE_ACTIVITY_RELAY_API_KEY` | Must match `RELAY_API_KEY` from the relay server |

These are set in `project.yml` and can be configured via Xcode build settings:
- Open the project in Xcode → select the **AirPosture** target → **Build Settings** tab
- Search for `LIVE_ACTIVITY_RELAY_BASE_URL` and `LIVE_ACTIVITY_RELAY_API_KEY`

---

## Build Settings & Environment

### Bundle Identifier

The default bundle ID is `com.example.airposture`. Change it to your own identifier:

- **`project.yml`**: Update `PRODUCT_BUNDLE_IDENTIFIER` for all targets
- **Xcode directly**: Select each target → **Signing & Capabilities** → update Bundle Identifier

### Development Team

Set your development team in Xcode:

1. Open the project in Xcode
2. Select the **AirPosture** target
3. Go to **Signing & Capabilities**
4. Select your team from the dropdown

Repeat for the **AirPostureLiveActivity** and **AirPostureAppTests** targets.

### Required Capabilities

The project configures the following capabilities automatically via `project.yml`:

- **Background Modes** → `Audio, AirPlay, and Picture in Picture` (for silent audio background tracking)
- **Background App Refresh**
- **Push Notifications**
- **Live Activities** (enabled via `Info.plist`)

### XcodeGen (Optional)

The project includes a `project.yml` file for [XcodeGen](https://github.com/YonasKolb/XcodeGen) — a tool that generates `.xcodeproj` files from a YAML spec. If you modify `project.yml`, regenerate the project:

```bash
xcodegen generate
```

The generated `.xcodeproj` is committed to the repo so you can open and build without XcodeGen installed.

---

## Project Structure

```
AirPosture/
├── AirPostureApp/              # Main iOS app target
│   ├── *.swift                 # App entry point, scene delegates
│   ├── ARSessionManager.swift  # ARKit body tracking
│   ├── HeadphoneMotionManager.swift # AirPods head tracking
│   ├── BodyPoseProcessor.swift # Posture classification
│   ├── Models/                 # Data models (PostureState, Session, etc.)
│   ├── Views/                  # SwiftUI views
│   │   ├── Components/         # Reusable UI components
│   │   └── Posture/            # Posture-specific views
│   ├── Services/               # Bluetooth, haptics, motion services
│   │   └── Motion/             # Posture evaluation, timing
│   ├── Architecture/           # Protocols and abstractions
│   │   └── Protocols/          # AvatarManaging, MotionTracking, etc.
│   └── Features/               # Feature-specific modules
├── AirPostureLiveActivity/     # Live Activity widget extension
│   ├── AirPostureLiveActivity.swift
│   ├── LiveActivityLockScreen.swift
│   ├── LiveActivityDynamicIsland.swift
│   └── LiveActivityComponents.swift
├── AirPostureShared/           # Shared code between app & widget
│   └── AirPostureActivityAttributes.swift
├── AirPostureCore/             # Reusable head-tracking & posture scoring package
│   ├── Package.swift
│   └── README.md               # Full docs for macOS/notch app integration
├── AirPostureAppTests/         # Unit tests
├── live-activity-relay/        # APNs relay server (Node.js)
│   ├── server.mjs
│   └── README.md
├── Tests/                      # Python-based hardware integration tests
├── project.yml                 # XcodeGen project spec
└── README.md                   # This file
```

---

## Running the App

### On a Physical Device

1. Connect your iPhone via USB or use Wireless Debugging
2. Select your device as the build target in Xcode
3. Press **Cmd+R** to build and run

> **Important:** ARKit body tracking requires a physical device with a TrueDepth camera (iPhone XS or later). Simulator has no camera or AirPods motion data.

### Features That Need AirPods

The following features require AirPods (or compatible headphones) to be connected:

- Head motion tracking / posture detection via `CMHeadphoneMotionManager`
- Tilt and lean angle visualization
- Background posture monitoring

The app will gracefully degrade and show connection status if AirPods aren't available.

### Test Suite

Run the unit tests from Xcode:

- **Cmd+U** to run all tests
- Or select individual test files from the **AirPostureAppTests** target

For hardware integration tests (requires real device with AirPods):

```bash
cd Tests
./TEST_NOW.sh          # Full test suite (requires real device with AirPods)
```

---

## AirPostureCore Package

The `AirPostureCore/` directory is a standalone Swift Package that wraps `CMHeadphoneMotionManager` for head-tracking and posture scoring. It can be used independently in other projects (iOS 18.0+ or macOS 14.0+).

See [AirPostureCore/README.md](AirPostureCore/README.md) for:

- Integration instructions for macOS notch/menu bar apps
- API reference for `AirPostureTracker` and `AirPostureSnapshot`
- Entitlements and sandbox requirements
- Mock providers for simulator testing
