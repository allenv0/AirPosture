import SwiftUI
import UserNotifications
import BackgroundTasks
import FirebaseCore
import os
#if os(iOS)
import UIKit
#endif

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AnalyticsManager.shared.configure()
        return true
    }
}
#endif

@main
struct AirPostureApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    @StateObject private var dependencies = AppDependencies()
    @AppStorage(UserDefaultsKeys.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    SimpleOnboardingFlow {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .preferredColorScheme(dependencies.themeManager.selectedTheme.colorScheme)
            .onAppear {
                setupNotifications()

                Logger.general.info("App launched safely with animations disabled for stability")
            }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    Logger.general.info("App terminating - performing IMMEDIATE cleanup")

                    let motionManager = dependencies.motionTracker
                    if motionManager.totalSessionTime > 0 && motionManager.currentSessionStore.currentSession != nil {
                        motionManager.currentSessionStore.endCurrentSession(
                            poorPostureDuration: motionManager.poorPostureDuration,
                            activeSessionDuration: motionManager.totalSessionTime,
                            runningWalkingDuration: motionManager.runningWalkingDuration
                        )
                    }

                    motionManager.stop()

                    AudioBackgroundManager.shared.disableBackgroundAudio()

                    Logger.general.info("Immediate termination cleanup completed")
                }
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .windowResizability(.contentMinSize(width: 300, height: 200))
        .defaultSize(width: 800, height: 600)
        #endif
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        registerBackgroundTasksOnce()

        Logger.general.info("Notification system initialized with background task registration")
    }

    private func registerBackgroundTasksOnce() {
        BackgroundTaskManager.shared.registerTasksIfNeeded()
        Logger.general.info("Background tasks registered at app launch")
    }
}
