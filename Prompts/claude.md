# AirPosture iOS App - Regeneration Prompt- v.0.01

## Summary

**AirPosture** is an iOS application (v0.3, build 21) that uses AirPods motion sensors to track head posture in real-time. The app features Live Activities with Dynamic Island integration, comprehensive background tracking, session history with charts, haptic feedback, and a premium SwiftUI user interface.

**Target Platform:** iOS 18.0+
**Language:** Swift 6.0+
**UI Framework:** SwiftUI
**Architectural Pattern:** MVVM with Manager pattern

---

## 1. PROJECT STRUCTURE

```
AirPosture/
├── App/
│   ├── AppDelegate.swift             # App lifecycle & setup
│   ├── SceneDelegate.swift           # Scene management
│   └── HeadTrackerApp.swift          # App entry point (@main)
│
├── Domain/
│   ├── Entities/
│   │   ├── Session.swift             # Core business entities
│   │   ├── UserPreferences.swift
│   │   ├── PostureMetrics.swift
│   │   └── Device.swift
│   ├── UseCases/
│   │   ├── TrackPostureUseCase.swift
│   │   ├── StartSessionUseCase.swift
│   │   ├── EndSessionUseCase.swift
│   │   └── SaveSessionUseCase.swift
│   └── Repositories/
│       ├── SessionRepository.swift   # Protocols only
│       ├── DeviceRepository.swift
│       └── PreferencesRepository.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── SessionRepositoryImpl.swift
│   │   ├── DeviceRepositoryImpl.swift
│   │   └── PreferencesRepositoryImpl.swift
│   ├── DataSources/
│   │   ├── Local/
│   │   │   ├── SessionDataSource.swift
│   │   │   └── PreferencesDataSource.swift
│   │   └── Remote/
│   │       └── (if needed for future API integration)
│   ├── Mappers/
│   │   ├── SessionMapper.swift
│   │   └── DeviceMapper.swift
│   └── Services/
│       ├── MotionTrackingService.swift
│       ├── BluetoothService.swift
│       ├── NotificationService.swift
│       ├── BackgroundService.swift
│       └── HapticService.swift
│
├── Presentation/
│   ├── Common/
│   │   ├── Base/
│   │   │   ├── BaseViewModel.swift
│   │   │   └── BaseView.swift
│   │   ├── Components/
│   │   │   ├── Buttons/
│   │   │   ├── Cards/
│   │   │   ├── ProgressIndicators/
│   │   │   └── Modals/
│   │   ├── Extensions/
│   │   │   ├── Color+Extensions.swift
│   │   │   ├── View+Extensions.swift
│   │   │   └── Font+Extensions.swift
│   │   └── Utils/
│   │       ├── Constants.swift
│   │       ├── DateFormatter+Extensions.swift
│   │       └── AnimationHelpers.swift
│   │
│   ├── Features/
│   │   ├── PostureTracking/
│   │   │   ├── Views/
│   │   │   │   ├── PostureTrackingView.swift
│   │   │   │   ├── PostureTrackingContainerView.swift
│   │   │   │   └── PostureSettingsView.swift
│   │   │   ├── Components/
│   │   │   │   ├── PostureVisualizerView.swift
│   │   │   │   ├── ProgressCirclesView.swift
│   │   │   │   └── PostureStatusIndicator.swift
│   │   │   └── ViewModels/
│   │   │       ├── PostureTrackingViewModel.swift
│   │   │       └── PostureSettingsViewModel.swift
│   │   │
│   │   ├── SessionHistory/
│   │   │   ├── Views/
│   │   │   │   ├── SessionHistoryView.swift
│   │   │   │   ├── SessionDetailView.swift
│   │   │   │   └── SessionChartsView.swift
│   │   │   ├── Components/
│   │   │   │   ├── SessionCard.swift
│   │   │   │   └── SessionChart.swift
│   │   │   └── ViewModels/
│   │   │       └── SessionHistoryViewModel.swift
│   │   │
│   │   ├── DeviceConnection/
│   │   │   ├── Views/
│   │   │   │   ├── DeviceConnectionView.swift
│   │   │   │   └── DevicePickerView.swift
│   │   │   ├── Components/
│   │   │   │   └── ConnectionStatusView.swift
│   │   │   └── ViewModels/
│   │   │       └── DeviceConnectionViewModel.swift
│   │   │
│   │   ├── Onboarding/
│   │   │   ├── Views/
│   │   │   │   ├── OnboardingView.swift
│   │   │   │   ├── OnboardingPageView.swift
│   │   │   │   └── PermissionsView.swift
│   │   │   └── ViewModels/
│   │   │       └── OnboardingViewModel.swift
│   │   │
│   │   └── Settings/
│   │       ├── Views/
│   │       │   ├── SettingsView.swift
│   │       │   ├── NotificationSettingsView.swift
│   │       │   └── AppearanceSettingsView.swift
│   │       ├── Components/
│   │       │   └── SettingsToggle.swift
│   │       └── ViewModels/
│   │           └── SettingsViewModel.swift
│   │
│   ├── Navigation/
│   │   ├── AppCoordinator.swift       # Navigation coordinator
│   │   ├── PostureCoordinator.swift
│   │   └── SettingsCoordinator.swift
│   │
│   └── Theme/
│       ├── AppTheme.swift
│       ├── Colors.swift
│       ├── Fonts.swift
│       └── Spacing.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   │   ├── Images/
│   │   ├── Icons/
│   │   └── Avatars/
│   ├── Info.plist
│   ├── Localizable.strings
│   └── entitlements/
│       ├── HeadTrackerApp.entitlements
│       └── LiveActivity.entitlements
│
├── Extensions/
│   └── LiveActivityExtension/
│       ├── AirPostureLiveActivity.swift
│       ├── AirPostureLiveActivityBundle.swift
│       ├── Views/
│       │   ├── DynamicIslandView.swift
│       │   ├── LockScreenView.swift
│       │   └── StandaloneView.swift
│       └── Assets.xcassets/
│
└── Tests/
    ├── UnitTests/
    │   ├── Domain/
    │   ├── Data/
    │   └── Presentation/
    └── UITests/
```

---

## 2. CORE FEATURES

### 2.1 AirPods Motion Tracking
- **Real-time head orientation:** Pitch, roll, yaw tracking via CMHeadphoneMotionManager
- **Supported Devices:**
  - AirPods Pro (all generations)
  - AirPods (3rd gen+)
  - AirPods Max
  - Beats earphones with spatial audio & dynamic head tracking
- **Hardware Detection:** Automatic device model identification
- **Posture Detection Algorithm:**
  - Configurable poor posture threshold (default: -22°)
  - Low-pass filter for smoothing (factor: 0.4)
  - 55 Hz UI update cap for performance
  - Motion data throttled to 12Hz maximum

### 2.2 Live Activities & Dynamic Island
- **4 View States:**
  1. **Compact Leading:** Rotating avatar (44x44) with pitch-based rotation
  2. **Compact Trailing:** Posture percentage with color-coded ring
  3. **Expanded Leading:** Rotating avatar + session timer + status badge
  4. **Expanded Trailing:** Premium animated progress ring (70x70)
  5. **Expanded Bottom:** Head angle + poor posture metrics
  6. **Minimal:** Status indicator circle
- **Lock Screen:** Full-screen display with dark gradient background
- **Update Throttling:** Maximum 2 Hz updates
- **Real-time Data:** Pitch, roll, posture percentage, session timer

### 2.3 Posture Coaching System
- **Configurable Thresholds:** Poor posture angle threshold (UserDefaults: "poorPostureThreshold")
- **Visual Feedback:**
  - Green circle (> -20°): Good posture
  - Orange/red circle (< -20°): Poor posture
  - Animated transitions
- **Warning Countdown (Optional):**
  - 10-second countdown when poor posture detected
  - Disabled by default (UserDefaults: "isWarningCountdownEnabled")
- **Recovery Countdown (Optional):**
  - 5-second countdown when returning to good posture
  - Disabled by default (UserDefaults: "isRecoveryCountdownEnabled")
- **Haptic Feedback (Optional):**
  - 0.2 second interval when in poor posture
  - Enabled by default (UserDefaults: "isHapticFeedbackEnabled")
  - Bad posture haptic (UserDefaults: "isBadPostureHapticEnabled")

### 2.4 Session Management
- **Session Tracking:**
  - Start time, end time
  - Poor posture duration
  - Active session duration
  - Running/walking duration (via CMMotionActivityManager)
- **Persistence:** UserDefaults-backed JSON storage
- **Session History:**
  - Pagination (10 sessions per page)
  - Timeframe filtering (Day, Week, Month, All Time)
  - Swift Charts visualization
  - Average good posture calculation
- **Session Notifications:** Summary on completion

### 2.5 Bluetooth Device Management
- **System Audio Route Picker:** MPVolumeView integration (like Spotify/Overcast)
- **Device Discovery:**
  - AVAudioSession current route inspection
  - Core Bluetooth scanning
  - Paired device retrieval
- **Auto-connection:** Direct connection to paired AirPods
- **Connection Monitoring:** Real-time status updates with alert callbacks

### 2.6 Background Tracking
- **Multiple Strategies:**
  1. Audio-based background tracking (AVAudioSession playback mode)
  2. Background task scheduler (BGTaskScheduler)
  3. Enhanced background manager with memory monitoring
- **Grace Period:** 30-second disconnection tolerance
- **Update Interval:** 1 second for background updates
- **Max Duration:** 5 minutes (300 updates)

### 2.7 User Interface
- **Theme System:** System, Light, Dark modes (ThemeManager)
- **Avatar Selection:** Bear, Cat, Dog, Tim (Cook), Alice, Bear Max
- **Premium Design:**
  - Glass morphism effects (.ultraThinMaterial)
  - Rainbow underglow effects
  - Gradient buttons (5-stop blue gradient)
  - Shadow depth (2-layer shadows)
  - SF Symbols icons
- **Onboarding Flow:** Permission request with checklist UI
- **Settings Panel:**
  - Poor posture threshold slider (-10° to -35°)
  - Haptic feedback toggles
  - Countdown toggles
  - Theme selection
  - Avatar selection
  - Notification mode selection

---

## 3. ARCHITECTURE PATTERNS

### 3.1 Clean Architecture Overview
The app follows Clean Architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    Views     │  │ ViewModels  │  │   Coordinators      │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Entities  │  │  Use Cases  │  │   Repositories      │ │
│  │             │  │             │  │   (Protocols)       │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Repositories │  │Data Sources │  │     Services        │ │
│  │(Impls)       │  │             │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 MVVM with Dependency Injection
```swift
// Domain Entity
struct Session: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date
    var poorPostureDuration: TimeInterval
    var activeSessionDuration: TimeInterval
    var runningWalkingDuration: TimeInterval
    var avatarType: String
}

// ViewModel with Dependency Injection
@MainActor
final class PostureTrackingViewModel: ObservableObject {
    @Published private(set) var pitch: Double = 0.0
    @Published private(set) var roll: Double = 0.0
    @Published private(set) var postureState: PostureState = .good(postureDuration: 0)
    
    private let trackPostureUseCase: TrackPostureUseCase
    private let startSessionUseCase: StartSessionUseCase
    
    init(
        trackPostureUseCase: TrackPostureUseCase,
        startSessionUseCase: StartSessionUseCase
    ) {
        self.trackPostureUseCase = trackPostureUseCase
        self.startSessionUseCase = startSessionUseCase
    }
}

// View
struct PostureTrackingView: View {
    @StateObject private var viewModel: PostureTrackingViewModel
    
    var body: some View {
        // UI implementation
    }
}
```

### 3.3 Use Case Pattern
```swift
protocol TrackPostureUseCase {
    func startTracking() async
    func stopTracking() async
    func getCurrentPosture() -> PostureMetrics
}

protocol StartSessionUseCase {
    func execute(avatarType: AvatarType) async throws -> Session
    func endSession(session: Session) async throws
}
```

### 3.4 Repository Pattern
```swift
// Domain Protocol
protocol SessionRepository {
    func save(_ session: Session) async throws
    func getAllSessions() async throws -> [Session]
    func getSession(by id: UUID) async throws -> Session?
}

// Data Layer Implementation
final class SessionRepositoryImpl: SessionRepository {
    private let dataSource: SessionDataSource
    private let mapper: SessionMapper
    
    init(dataSource: SessionDataSource, mapper: SessionMapper) {
        self.dataSource = dataSource
        self.mapper = mapper
    }
    
    func save(_ session: Session) async throws {
        // Implementation
    }
    
    // ... other methods
}
```

### 3.5 Coordinator Pattern for Navigation
```swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }
    
    func start()
}

final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let postureCoordinator = PostureCoordinator(
            navigationController: navigationController
        )
        childCoordinators.append(postureCoordinator)
        postureCoordinator.start()
    }
}
```

---

## 4. KEY IMPLEMENTATION DETAILS

### 4.1 Motion Tracking Service Implementation
```swift
import CoreMotion

// Data Layer
final class MotionTrackingService {
    private var motionManager = CMHeadphoneMotionManager()
    private let motionProcessingQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.airposture.motionProcessing"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    func startTracking() -> AsyncStream<PostureMetrics> {
        AsyncStream { continuation in
            motionManager.startDeviceMotionUpdates(to: motionProcessingQueue) { motion, error in
                guard let motion = motion else {
                    continuation.finish()
                    return
                }
                
                let metrics = PostureMetrics(
                    pitch: motion.attitude.pitch,
                    roll: motion.attitude.roll,
                    yaw: motion.attitude.yaw,
                    timestamp: Date()
                )
                
                continuation.yield(metrics)
            }
        }
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// Domain Layer
final class TrackPostureUseCaseImpl: TrackPostureUseCase {
    private let motionTrackingService: MotionTrackingService
    private let sessionRepository: SessionRepository
    private var currentStream: AsyncStream<PostureMetrics>?
    
    init(
        motionTrackingService: MotionTrackingService,
        sessionRepository: SessionRepository
    ) {
        self.motionTrackingService = motionTrackingService
        self.sessionRepository = sessionRepository
    }
    
    func startTracking() async {
        currentStream = motionTrackingService.startTracking()
        for await metrics in currentStream! {
            // Process posture metrics
            await processPostureMetrics(metrics)
        }
    }
    
    func stopTracking() async {
        motionTrackingService.stopTracking()
        currentStream = nil
    }
    
    func getCurrentPosture() -> PostureMetrics {
        // Return current posture state
    }
    
    private func processPostureMetrics(_ metrics: PostureMetrics) async {
        // Apply low-pass filter and posture detection
    }
}
```

### 4.2 Posture Detection Algorithm
```swift
// Domain Entity
enum PostureState {
    case good(postureDuration: TimeInterval)
    case poor(postureDuration: TimeInterval)
}

// Domain Entity
struct PostureMetrics {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let timestamp: Date
}

// Domain Use Case
protocol PostureDetectionUseCase {
    func detectPostureState(from metrics: PostureMetrics) -> PostureState
    func isPoorPosture(_ pitch: Double) -> Bool
}

final class PostureDetectionUseCaseImpl: PostureDetectionUseCase {
    private let poorPostureThreshold: Double
    
    init(poorPostureThreshold: Double = -22.0) {
        self.poorPostureThreshold = poorPostureThreshold
    }
    
    func detectPostureState(from metrics: PostureMetrics) -> PostureState {
        if isPoorPosture(metrics.pitch) {
            return .poor(postureDuration: 0)
        } else {
            return .good(postureDuration: 0)
        }
    }
    
    func isPoorPosture(_ pitch: Double) -> Bool {
        return pitch < poorPostureThreshold
    }
}
```

### 4.3 Live Activity Service Implementation
```swift
// Data Layer
@available(iOS 16.1, *)
final class LiveActivityService {
    private var currentActivity: Activity<AirPostureActivityAttributes>?
    private let notificationService: NotificationService
    
    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }
    
    func startLiveActivity(for session: Session) async throws {
        let attributes = AirPostureActivityAttributes(
            sessionId: session.id,
            avatarAssetName: session.avatarType,
            userDisplayName: nil,
            sessionStartTime: session.startTime
        )
        
        let activity = try Activity<AirPostureActivityAttributes>.request(
            attributes: attributes,
            contentState: AirPostureActivityAttributes.ContentState(
                poorPosturePercent: 0,
                postureStatus: .good,
                sessionTimer: "00:00",
                lastUpdate: Date(),
                pitch: 0,
                roll: 0,
                goodPosturePercent: 100
            ),
            pushType: nil
        )
        
        self.currentActivity = activity
    }
    
    func updateLiveActivity(
        percent: Int,
        status: PostureStatus,
        timer: String,
        pitch: Double = 0,
        roll: Double = 0
    ) async {
        guard let activity = currentActivity else { return }
        
        let state = AirPostureActivityAttributes.ContentState(
            poorPosturePercent: percent,
            postureStatus: status,
            sessionTimer: timer,
            lastUpdate: Date(),
            pitch: pitch,
            roll: roll,
            goodPosturePercent: 100 - percent
        )
        
        await activity.update(using: state)
    }
    
    func endLiveActivity() async {
        guard let activity = currentActivity else { return }
        await activity.end(dismissalPolicy: .default)
        currentActivity = nil
    }
}
}
```

### 4.4 Bluetooth Service Implementation
```swift
import AVFoundation
import MediaPlayer

// Data Layer
protocol BluetoothServiceProtocol {
    func showDevicePicker() async throws
    func getCurrentDevice() async -> Device?
    func monitorDeviceConnection() -> AsyncStream<Device>
}

final class BluetoothService: NSObject, BluetoothServiceProtocol {
    private var centralManager: CBCentralManager?
    private let deviceContinuation = AsyncStream<Device>.makeStream()
    
    func showDevicePicker() async throws {
        guard let centralManager = centralManager else {
            throw BluetoothError.centralManagerNotInitialized
        }

        if centralManager.state == .poweredOn {
            try await openSystemAudioRoutePicker()
        } else {
            throw BluetoothError.bluetoothDisabled
        }
    }

    private func openSystemAudioRoutePicker() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let routePickerView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                routePickerView.showsVolumeSlider = false
                routePickerView.showsRouteButton = true

                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    continuation.resume(throwing: BluetoothError.noWindowAvailable)
                    return
                }

                window.addSubview(routePickerView)

                // Trigger the route picker
                for subview in routePickerView.subviews {
                    if let button = subview as? UIButton {
                        button.sendActions(for: .touchUpInside)
                        break
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    routePickerView.removeFromSuperview()
                    continuation.resume()
                }

                self.setupSystemPickerDismissalMonitoring()
            }
        }
    }
    
    func getCurrentDevice() async -> Device? {
        // Return current connected device
        return nil
    }
    
    func monitorDeviceConnection() -> AsyncStream<Device> {
        return deviceContinuation.stream
    }
}

enum BluetoothError: Error {
    case centralManagerNotInitialized
    case bluetoothDisabled
    case noWindowAvailable
}
```

### 4.5 Session Repository Implementation
```swift
// Data Layer - Local DataSource
protocol SessionDataSource {
    func save(_ dto: SessionDTO) async throws
    func getAll() async throws -> [SessionDTO]
    func getById(_ id: UUID) async throws -> SessionDTO?
}

final class UserDefaultsSessionDataSource: SessionDataSource {
    private let sessionsKey = "sessions"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func save(_ dto: SessionDTO) async throws {
        var allSessions = try await getAll()
        
        // Remove existing session with same ID if present
        allSessions.removeAll { $0.id == dto.id }
        
        // Add updated session
        allSessions.append(dto)
        
        let data = try encoder.encode(allSessions)
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }
    
    func getAll() async throws -> [SessionDTO] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            return []
        }
        
        return try decoder.decode([SessionDTO].self, from: data)
    }
    
    func getById(_ id: UUID) async throws -> SessionDTO? {
        let allSessions = try await getAll()
        return allSessions.first { $0.id == id }
    }
}

// Data Layer - Repository Implementation
final class SessionRepositoryImpl: SessionRepository {
    private let dataSource: SessionDataSource
    private let mapper: SessionMapper
    
    init(dataSource: SessionDataSource, mapper: SessionMapper) {
        self.dataSource = dataSource
        self.mapper = mapper
    }
    
    func save(_ session: Session) async throws {
        let dto = mapper.toDTO(entity: session)
        try await dataSource.save(dto)
    }
    
    func getAllSessions() async throws -> [Session] {
        let dtos = try await dataSource.getAll()
        return dtos.compactMap { mapper.toEntity(dto: $0) }
    }
    
    func getSession(by id: UUID) async throws -> Session? {
        guard let dto = try await dataSource.getById(id) else { return nil }
        return mapper.toEntity(dto: dto)
    }
}

// Data Layer - Mapper
final class SessionMapper {
    func toDTO(entity: Session) -> SessionDTO {
        let formatter = ISO8601DateFormatter()
        return SessionDTO(
            id: entity.id,
            startTime: formatter.string(from: entity.startTime),
            endTime: formatter.string(from: entity.endTime),
            poorPostureDuration: entity.poorPostureDuration,
            activeSessionDuration: entity.activeSessionDuration,
            runningWalkingDuration: entity.runningWalkingDuration,
            avatarType: entity.avatarType
        )
    }
    
    func toEntity(dto: SessionDTO) -> Session? {
        let formatter = ISO8601DateFormatter()
        guard 
            let startDate = formatter.date(from: dto.startTime),
            let endDate = formatter.date(from: dto.endTime)
        else { return nil }
        
        return Session(
            id: dto.id,
            startTime: startDate,
            endTime: endDate,
            poorPostureDuration: dto.poorPostureDuration,
            activeSessionDuration: dto.activeSessionDuration,
            runningWalkingDuration: dto.runningWalkingDuration,
            avatarType: dto.avatarType
        )
    }
}
```

---

## 5. CONFIGURATION FILES

### 5.1 Info.plist
```xml
<key>CFBundleDisplayName</key>
<string>AirPosture</string>
<key>CFBundleShortVersionString</key>
<string>0.3</string>
<key>CFBundleVersion</key>
<string>19</string>

<!-- Permissions -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to discover and connect to your AirPods Pro for motion tracking.</string>
<key>NSMotionUsageDescription</key>
<string>This app needs access to motion data from your AirPods Pro to display head orientation and track your physical activity for better session insights.</string>
<key>NSUserNotificationsUsageDescription</key>
<string>This app sends notifications to alert you about posture warnings and session updates.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- Live Activities -->
<key>NSSupportsLiveActivities</key>
<true/>

<!-- Background Tasks -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.allenleee.AirPosture.background-refresh</string>
</array>
```

### 5.2 HeadTrackerApp.entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.developer.live-activities</key>
<true/>
```

### 5.3 Live Activity Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.developer.live-activities</key>
<true/>
```

---

## 6. DATA MODELS

### 6.1 Domain Entities
```swift
// Session Entity - Core business object
struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    var endTime: Date
    var poorPostureDuration: TimeInterval
    var activeSessionDuration: TimeInterval = 0
    var runningWalkingDuration: TimeInterval = 0
    var avatarType: String = "bear-neck"

    var totalDuration: TimeInterval {
        return activeSessionDuration > 0
            ? activeSessionDuration
            : endTime.timeIntervalSince(startTime)
    }

    var poorPosturePercentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(((totalDuration - poorPostureDuration) / totalDuration) * 100)
    }

    var wasRunningOrWalking: Bool {
        return runningWalkingDuration > 60
    }
}

// PostureMetrics Entity - Captures motion data
struct PostureMetrics {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let timestamp: Date
}

// Device Entity - Represents connected headphones
struct Device: Identifiable, Codable {
    let id: UUID
    let name: String
    let model: String
    let isConnected: Bool
    let connectionDate: Date
}

// UserPreferences Entity
struct UserPreferences: Codable {
    var poorPostureThreshold: Double
    var isHapticFeedbackEnabled: Bool
    var isWarningCountdownEnabled: Bool
    var isRecoveryCountdownEnabled: Bool
    var selectedAvatar: AvatarType
    var selectedTheme: AppTheme
    
    static let `default` = UserPreferences(
        poorPostureThreshold: -22.0,
        isHapticFeedbackEnabled: true,
        isWarningCountdownEnabled: false,
        isRecoveryCountdownEnabled: false,
        selectedAvatar: .bearNeck,
        selectedTheme: .system
    )
}
```

### 6.2 Data Transfer Objects (DTOs)
```swift
// SessionDTO - For API communication or persistence
struct SessionDTO: Codable {
    let id: UUID
    let startTime: String  // ISO8601 format
    var endTime: String
    var poorPostureDuration: Double
    var activeSessionDuration: Double
    var runningWalkingDuration: Double
    var avatarType: String
    
    func toEntity() -> Session? {
        let formatter = ISO8601DateFormatter()
        guard 
            let startDate = formatter.date(from: startTime),
            let endDate = formatter.date(from: endTime)
        else { return nil }
        
        return Session(
            id: id,
            startTime: startDate,
            endTime: endDate,
            poorPostureDuration: poorPostureDuration,
            activeSessionDuration: activeSessionDuration,
            runningWalkingDuration: runningWalkingDuration,
            avatarType: avatarType
        )
    }
    
    static func from(entity: Session) -> SessionDTO {
        let formatter = ISO8601DateFormatter()
        return SessionDTO(
            id: entity.id,
            startTime: formatter.string(from: entity.startTime),
            endTime: formatter.string(from: entity.endTime),
            poorPostureDuration: entity.poorPostureDuration,
            activeSessionDuration: entity.activeSessionDuration,
            runningWalkingDuration: entity.runningWalkingDuration,
            avatarType: entity.avatarType
        )
    }
}

// Live Activity DTOs
@available(iOS 16.1, *)
public struct AirPostureActivityAttributes: ActivityAttributes {
    @available(iOS 16.1, *)
    public struct ContentState: Codable, Hashable {
        public var poorPosturePercent: Int
        public var postureStatus: PostureStatus
        public var sessionTimer: String
        public var lastUpdate: Date
        public var pitch: Double
        public var roll: Double
        public var goodPosturePercent: Int
    }

    public var sessionId: UUID
    public var avatarAssetName: String
    public var userDisplayName: String?
    public var sessionStartTime: Date
}

@available(iOS 16.1, *)
public enum PostureStatus: String, Codable, Hashable {
    case good
    case poor
    case unknown
}
```

### 6.3 Value Objects
```swift
enum AvatarType: String, CaseIterable {
    case bear = "bear-neck"
    case cat = "cat-neck"
    case dog = "dog-neck"
    case tim = "tim-neck"
    case alice = "alice-neck"
    case bear2 = "bear-neck2"

    var displayName: String {
        switch self {
        case .bear: return "Bear"
        case .cat: return "Kitty"
        case .dog: return "Samoyed"
        case .tim: return "Let Tim Cook"
        case .alice: return "Alice"
        case .bear2: return "Bear Max"
        }
    }
}
```

---

## 7. UI COMPONENTS

### 7.1 Main View Structure with Dependency Injection
```swift
// Presentation Layer - Feature: PostureTracking
struct PostureTrackingView: View {
    @StateObject private var viewModel: PostureTrackingViewModel
    
    init(viewModel: PostureTrackingViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: viewModel.themeColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header with settings button
                    headerView

                    // Main posture visualizer (rotating avatar)
                    PostureVisualizerView(
                        postureMetrics: viewModel.currentPosture
                    )

                    // Progress circles
                    ProgressCirclesView(
                        goodPosturePercent: viewModel.goodPosturePercentage,
                        poorPosturePercent: viewModel.poorPosturePercentage
                    )

                    // Session timer
                    sessionTimerView

                    // Start/Stop button
                    sessionButton

                    // Session history
                    SessionHistoryView(
                        sessions: viewModel.sessions
                    )
                }
            }
        }
        .preferredColorScheme(viewModel.theme.colorScheme)
    }
}
```

### 7.2 Posture Visualizer Component
```swift
// Presentation Layer - Shared Component
struct PostureVisualizerView: View {
    let postureMetrics: PostureMetrics
    let avatarType: AvatarType
    
    private var postureColor: Color {
        postureMetrics.pitch < -22.0
            ? Color(red: 1.0, green: 0.31, blue: 0.0)  // Red
            : Color(red: 0.0, green: 0.8, blue: 0.4)  // Green
    }

    var body: some View {
        ZStack {
            // Outer circle with stroke
            Circle()
                .stroke(postureColor, lineWidth: 8)
                .frame(width: 200, height: 200)
                .shadow(color: postureColor.opacity(0.3), radius: 8)

            // Rotating avatar
            Image(avatarType.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(postureMetrics.pitch))
                .animation(.easeInOut(duration: 0.3), value: postureMetrics.pitch)
        }
    }
}

// ViewModel for the PostureTrackingView
@MainActor
final class PostureTrackingViewModel: ObservableObject {
    @Published private(set) var currentPosture: PostureMetrics = PostureMetrics(pitch: 0, roll: 0, yaw: 0, timestamp: Date())
    @Published private(set) var goodPosturePercentage: Int = 100
    @Published private(set) var poorPosturePercentage: Int = 0
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var theme: AppTheme = .system
    
    private let trackPostureUseCase: TrackPostureUseCase
    private let getSessionHistoryUseCase: GetSessionHistoryUseCase
    private let themeRepository: ThemeRepository
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property for theme colors
    var themeColors: [Color] {
        theme.gradientColors
    }
    
    init(
        trackPostureUseCase: TrackPostureUseCase,
        getSessionHistoryUseCase: GetSessionHistoryUseCase,
        themeRepository: ThemeRepository
    ) {
        self.trackPostureUseCase = trackPostureUseCase
        self.getSessionHistoryUseCase = getSessionHistoryUseCase
        self.themeRepository = themeRepository
        
        loadTheme()
        loadSessionHistory()
        startPostureTracking()
    }
    
    private func loadTheme() {
        themeRepository.getCurrentTheme()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.theme = theme
            }
            .store(in: &cancellables)
    }
    
    private func loadSessionHistory() {
        Task {
            let sessions = await getSessionHistoryUseCase.execute()
            await MainActor.run {
                self.sessions = sessions
            }
        }
    }
    
    private func startPostureTracking() {
        Task {
            for await metrics in trackPostureUseCase.startTracking() {
                await MainActor.run {
                    self.currentPosture = metrics
                    updatePosturePercentages()
                }
            }
        }
    }
    
    private func updatePosturePercentages() {
        // Update percentages based on current session data
    }
}
```

### 7.3 Premium Button Styling
```swift
private let startButtonGradient: [Color] = [
    Color(red: 0.0, green: 0.4, blue: 1.0),
    Color(red: 0.0, green: 0.5, blue: 0.95),
    Color(red: 0.0, green: 0.6, blue: 0.9),
    Color(red: 0.0, green: 0.5, blue: 0.95),
    Color(red: 0.0, green: 0.4, blue: 1.0)
]

Button(action: startSession) {
    Text("Start Session")
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 46)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Blue gradient
                Capsule()
                    .fill(LinearGradient(startButtonGradient, startPoint: .top, endPoint: .bottom))

                // Glass morphism
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)

                // Rainbow inner highlight
                Capsule()
                    .stroke(rainbowGradient, lineWidth: 1.5)
            }
        )
        // Rainbow underglow
        .background(
            Capsule()
                .fill(rainbowGradient)
                .blur(radius: 12)
                .offset(y: 6)
        )
}
```

---

## 8. ASSETS & RESOURCES

### 8.1 Avatar Images (Assets.xcassets)
- `bear-neck.png` - Main bear avatar
- `bear-neck2.png` - Bear Max variant
- `bear-launch.png`, `bear-launch2.png` - Launch screen bears
- `bear-running.png` - Running state bear
- `cat-neck.png` - Cat avatar
- `dog-neck.png` - Samoyed dog avatar
- `tim-neck.png` - Tim Cook avatar
- `alice-neck.png` - Alice avatar

### 8.2 App Icons
- `AppIcon.appiconset/` - Multiple sizes (iOS App Icon)
- `AppIconDefault.png` - Default icon
- `AppIconDark.png` - Dark mode variant

### 8.3 Color Palette
```swift
extension Color {
    static let postureGood = Color(red: 0, green: 0.8, blue: 0.4)      // #00CC66
    static let posturePoor = Color(red: 1, green: 0.31, blue: 0)       // #FF4F00
    static let postureCaution = Color(red: 1, green: 0.76, blue: 0)    // #FFC200
    static let postureMotion = Color(red: 0, green: 0.75, blue: 1)     // #00BFFF
}
```

---

## 9. DEPENDENCIES

### 9.1 System Frameworks
- SwiftUI - UI framework
- CoreMotion - Motion tracking
- CoreBluetooth - Device discovery
- AVFoundation - Audio management
- UserNotifications - Push notifications
- ActivityKit - Live Activities
- WidgetKit - Dynamic Island widgets
- Combine - Reactive programming
- Charts - Data visualization
- Foundation - Core iOS functionality

### 9.2 External Dependencies (Package.swift)
```swift
dependencies: [
    .package(url: "https://github.com/TelemetryDeck/SwiftClient", from: "2.9.4")
]
```

---

## 10. BUILD CONFIGURATION

### 10.1 Project Settings
- **Bundle ID:** `com.allenleee.AirPosture`
- **Deployment Target:** iOS 18.0
- **Swift Version:** 6.0+
- **Xcode Version:** 16.0+

### 10.2 Build Phases
1. Compile Sources (all Swift files)
2. Copy Bundle Resources (Assets.xcassets)
3. Embed Foundation Extensions (AirPostureLiveActivity)
4. Link Binary With Libraries (all frameworks)

---

## 11. USER FLOW

### 11.1 First Launch
1. Show `SimpleOnboardingFlow` view
2. Display animated bear avatar with Apple-inspired aura effects
3. Present "Allow Access" button
4. Show `PermissionChecklistSheet` with:
   - Bluetooth permission request
   - Motion permission request
   - Device support information
5. On completion, transition to main `ContentView`

### 11.2 Main App Flow
1. User taps "Connect AirPods" button
2. `BluetoothManager.showBluetoothDevicePicker()` opens system audio route picker
3. User selects AirPods from system sheet
4. `HeadphoneMotionManager.startTracking()` begins motion updates
5. User taps "Start Session" button
6. `LiveActivityController.start()` creates Live Activity
7. Real-time posture tracking begins with UI updates
8. Session data saved to `SessionStore`
9. User taps "End Session" button
10. `LiveActivityController.end()` dismisses Live Activity
11. Session summary notification sent

---

## 12. PERFORMANCE OPTIMIZATIONS

### 12.1 Motion Data Throttling
```swift
private let uiMotionDispatchInterval: TimeInterval = 1.0 / 15.0  // 15 Hz UI update cap
private let motionUpdateInterval: TimeInterval = 1.0  // 1 second for background updates
```

### 12.2 Live Activity Throttling
```swift
// Throttle: send at most ~2 Hz and only on meaningful change
guard timeSinceLast >= 0.5 || statusChanged || percentDelta >= 1 else {
    return
}
```

### 12.3 Memory Management
```swift
// Weak references in closures
[weak self] in
    guard let self = self else { return }
    // ...
}

// Background queue for heavy operations
private let dataQueue = DispatchQueue(label: "com.airposture.data", qos: .utility)

// Coalesced motion processing
private final class MotionSampleBuffer {
    // Thread-safe buffer for latest motion sample
}
```

### 12.4 Image Caching
```swift
class SimpleImageCache {
    static let shared = SimpleImageCache()
    private var cache: [String: PlatformImage] = [:]

    func preloadImageSynchronously(_ name: String) {
        if let image = PlatformImage(named: name) {
            cache[name] = image
        }
    }
}
```

---

## 13. TESTING CONSIDERATIONS

### 13.1 Simulator Mode
```swift
#if targetEnvironment(simulator)
    private let isSimulator = true
#else
    private let isSimulator = false
#endif

// Simulator requires manual session start
if isSimulator {
    self.connectionStatus = "Simulator ready - tap Start to begin"
}
```

### 13.2 Debug Logging
```swift
// Motion updates
print("📊 Motion: pitch=\(String(format: "%.1f", pitch))° roll=\(String(format: "%.1f", roll))°")

// Live Activity updates
print("📊 Live Activity Update: \(percent)% (\(status))")

// Session events
print("📱 Session ending - Duration: \(totalDuration)s, Poor posture: \(poorPosturePercentage)%")
```

---

## 14. REGRESSION CHECKLIST

When regenerating this app, ensure the following are implemented:

### Architecture & Structure
- [ ] Clean Architecture with Domain/Data/Presentation layers
- [ ] Feature-based organization in Presentation layer
- [ ] Dependency injection throughout the app
- [ ] Use Cases for all business logic operations
- [ ] Repository pattern with protocol/implementation separation
- [ ] Coordinator pattern for navigation

### Core Functionality
- [ ] CMHeadphoneMotionManager integration via MotionTrackingService
- [ ] Posture detection via PostureDetectionUseCase
- [ ] Session management via SessionRepository and related Use Cases
- [ ] Bluetooth connectivity via BluetoothService
- [ ] Live Activity management via LiveActivityService

### Data Flow
- [ ] DTOs for data persistence and API communication
- [ ] Mappers between Entities and DTOs
- [ ] Async/await pattern throughout data layer
- [ ] Combine for reactive UI updates in ViewModels

### UI Implementation
- [ ] SwiftUI Views with proper MVVM pattern
- [ ] ViewModels injected into Views
- [ ] Theme management via ThemeRepository
- [ ] Component-based reusable UI elements
- [ ] Navigation handled by Coordinators

### Performance & Optimization
- [ ] Low-pass filter (factor: 0.4) for motion data smoothing
- [ ] 15 Hz UI update cap with motion coalescing
- [ ] Live Activity throttling (~2 Hz max)
- [ ] Memory management with weak references
- [ ] Image caching for launch screen
- [ ] Background task optimization

### Configuration & Integration
- [ ] Proper entitlements configuration
- [ ] Info.plist permission descriptions
- [ ] Background modes configuration
- [ ] Live Activity extension configuration


---

## 15. FINAL NOTES

This AirPosture app represents a production-ready iOS application with:
- **Advanced iOS 18 features** (Live Activities, Dynamic Island)
- **Sophisticated motion tracking** (CMHeadphoneMotionManager)
- **Premium UI design** (Glass morphism, gradients, animations)
- **Robust background tracking** (Multiple strategies with fallbacks)
- **Comprehensive session management** (Persistence, charts, history)
- **Extensive configuration options** (Thresholds, toggles, themes, avatars)

The codebase follows practices including:
- MainActor for UI thread safety
- Async/await for non-blocking operations
- Combine for reactive programming
- Weak references to prevent retain cycles
- Proper error handling throughout
- Extensive logging for debugging

**Estimated Implementation Time:** 40-60 hours for experienced iOS developer

**Key Success Metrics:**
- Live Activities update smoothly at 2 Hz without lag
- Motion data is accurate with proper filtering
- Background tracking continues for 50+ minutes
- Session data persists correctly across app launches
- UI remains responsive at 60 FPS during tracking
- Battery consumption is reasonable (< 20% per hour)
