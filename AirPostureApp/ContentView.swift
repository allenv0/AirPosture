#if os(iOS)
import UIKit
#endif
import SwiftUI
import os

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case fitness = "Fitness"
        case personalize = "Personalize"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home:
                return "headphones"
            case .fitness:
                return "figure.flexibility"
            case .personalize:
                return "figure.stand"
            case .settings:
                return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PostureHomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            FitnessComingSoonView()
                .tabItem {
                    Label(Tab.fitness.rawValue, systemImage: Tab.fitness.icon)
                }
                .tag(Tab.fitness)

            PersonalizeRootView()
                .tabItem {
                    Label(Tab.personalize.rawValue, systemImage: Tab.personalize.icon)
                }
                .tag(Tab.personalize)

            SettingsRootView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tabViewStyle(.automatic)
        .tint(.blue)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .onChange(of: scenePhase, handleScenePhaseChange)
    }

    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .active {
            Logger.ui.info("App became active - tracking continues")
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                LiveActivityController.shared.restoreOrphanedActivitiesIfNeeded()
            }
            #endif
        } else if newPhase == .background {
            Logger.ui.info("App moved to background - tracking continues if session active")
        }
    }
}

#Preview {
    ContentView()
}
