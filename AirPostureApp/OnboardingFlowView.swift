import SwiftUI
import CoreBluetooth
import CoreMotion
import os
#if os(iOS)
import UIKit
#endif

struct SimpleOnboardingFlow: View {
    @State private var isAnimating = false
    @State private var isButtonPressed = false
    @State private var showPermissionSheet = false
    let onComplete: () -> Void

    private let startButtonGradient: [Color] = [
        Color(red: 0.0, green: 0.4, blue: 1.0),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.6, blue: 0.9),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.4, blue: 1.0)
    ]

    private let startButtonGradientNew: [Color] = [
        Color(red: 0.4, green: 0.8, blue: 1.0),
        Color(red: 0.3, green: 0.6, blue: 1.0),
        Color(red: 0.2, green: 0.4, blue: 0.9)
    ]

    var body: some View {
        ZStack {
            Group {
                #if os(iOS)
                Color(UIColor.systemBackground)
                #else
                Color(NSColor.windowBackgroundColor)
                #endif
            }
            .ignoresSafeArea()

            VStack(spacing: 70) {
                Spacer(minLength: 40)

                VStack(spacing: 50) {
                    Group {
                        if let cachedImage = SimpleImageCache.shared.getCachedImage("bear-launch2") {
                            Image(uiImage: cachedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 98, height: 98)
                                        } else {
                            Image("bear-neck")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 98, height: 98)
                                  }
                    }
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color(.systemBackground).opacity(0.1),
                                                Color.clear
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 56
                                        )
                                    )
                                    .frame(width: 140, height: 140)

                                Circle()
                                    .stroke(
                                        Color(.systemBlue).opacity(0.2),
                                        lineWidth: 4
                                    )
                                    .scaleEffect(1.25)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color(.systemRed).opacity(0.4), location: 0.0),
                                                .init(color: Color(.systemOrange).opacity(0.35), location: 0.17),
                                                .init(color: Color(.systemYellow).opacity(0.3), location: 0.33),
                                                .init(color: Color(.systemGreen).opacity(0.3), location: 0.5),
                                                .init(color: Color(.systemTeal).opacity(0.35), location: 0.67),
                                                .init(color: Color(.systemBlue).opacity(0.4), location: 0.83),
                                                .init(color: Color(.systemIndigo).opacity(0.35), location: 1.0)
                                            ]),
                                            center: .center
                                        ),
                                        lineWidth: 2
                                    )
                                    .scaleEffect(1.35)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .stroke(
                                        Color(.systemGray6).opacity(0.5),
                                        lineWidth: 1
                                    )
                                    .scaleEffect(1.15)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color(.systemBackground).opacity(0.85), location: 0.0),
                                                .init(color: Color(.systemGray6).opacity(0.4), location: 0.7),
                                                .init(color: Color.clear, location: 1.0)
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 28
                                        )
                                    )
                                    .frame(width: 112, height: 112)

                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.white.opacity(0.0), location: 0.0),
                                                .init(color: Color.white.opacity(0.5), location: 0.5),
                                                .init(color: Color.white.opacity(0.0), location: 1.0)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                                    .scaleEffect(1.20)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color.black.opacity(0.04),
                                                Color.clear
                                            ]),
                                            center: .center,
                                            startRadius: 35,
                                            endRadius: 49
                                        )
                                    )
                                    .frame(width: 140, height: 140)

                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color(.systemBackground).opacity(0.95), location: 0.0),
                                                .init(color: Color(.systemGray6).opacity(0.6), location: 0.7),
                                                .init(color: Color.clear, location: 1.0)
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 35
                                        )
                                    )
                                    .frame(width: 126, height: 126)

                                Group {
                                    Circle()
                                        .fill(Color(.systemRed).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 53, y: 46)

                                    Circle()
                                        .fill(Color(.systemYellow).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 60, y: 41)

                                    Circle()
                                        .fill(Color(.systemGreen).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 46, y: 41)

                                    Circle()
                                        .fill(Color(.systemBlue).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 53, y: 35)

                                    Circle()
                                        .fill(Color(.systemPurple).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 39, y: 46)

                                    Circle()
                                        .fill(Color(.systemOrange).opacity(0.7))
                                        .frame(width: 2, height: 2)
                                        .position(x: 67, y: 46)
                                }

                                Circle()
                                    .stroke(
                                        Color(.systemGray5).opacity(0.4),
                                        lineWidth: 0.5
                                    )
                                    .scaleEffect(1.10)
                                    .frame(width: 98, height: 98)
                                    .blur(radius: 1.5)

                                Circle()
                                    .stroke(Color(.systemRed).opacity(0.6), lineWidth: 1)
                                    .scaleEffect(1.05)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .stroke(Color(.systemBlue).opacity(0.5), lineWidth: 0.5)
                                    .scaleEffect(1.08)
                                    .frame(width: 98, height: 98)

                                Circle()
                                    .stroke(Color(.systemGreen).opacity(0.4), lineWidth: 0.5)
                                    .scaleEffect(1.12)
                                    .frame(width: 98, height: 98)
                            }
                            .accessibilityHidden(true)
                        )

                    VStack(spacing: 8) {
                        Text("Welcome to AirPosture")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: startButtonGradientNew,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .accessibilityLabel("Welcome")

                        Text("Track your posture with your AirPods")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                                }
                }

                VStack(spacing: 16) {
                    Button(action: {
                        #if os(iOS)
                        HapticManager.shared.impact(style: .heavy)
                        #endif
                        showPermissionSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))

                            Text("Allow Access")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .padding(.horizontal, 46)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: startButtonGradient,
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.6)

                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.9),
                                                Color.red.opacity(0.6),
                                                Color.orange.opacity(0.6),
                                                Color.yellow.opacity(0.6),
                                                Color.green.opacity(0.6),
                                                Color.blue.opacity(0.6),
                                                Color.indigo.opacity(0.6),
                                                Color.purple.opacity(0.6),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                                    .padding(1)

                                Capsule()
                                    .stroke(
                                        Color.black.opacity(0.25),
                                        lineWidth: 1.5
                                    )
                            }
                        )
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.9),
                                            Color.orange.opacity(0.9),
                                            Color.yellow.opacity(0.9),
                                            Color.green.opacity(0.9),
                                            Color.blue.opacity(0.9),
                                            Color.indigo.opacity(0.9),
                                            Color.purple.opacity(0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .blur(radius: 12)
                                .offset(y: 6)
                                .scaleEffect(1.3)
                                .opacity(0.8)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Allow Access")
                    .accessibilityHint("Double tap to grant permissions")
                    .scaleEffect(isButtonPressed ? 0.98 : 1.0)
                    .scaleEffect(1.0)
                    .opacity(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isButtonPressed)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = true
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isButtonPressed = false
                            }
                        }
                    }

                    Text("We need Bluetooth and Motion permissions to connect to your AirPods and track your posture")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
        }
        .onAppear {
            AnalyticsManager.shared.logScreenView(screenClass: "SimpleOnboardingFlow", screenName: "Onboarding Welcome")
            Logger.ui.info("Onboarding screen ready with animations disabled")
        }
        .sheet(isPresented: $showPermissionSheet) {
            PermissionChecklistSheet(
                onComplete: {
                    completeOnboarding()
                }
            )
            .onAppear {
                AnalyticsManager.shared.logScreenView(screenClass: "PermissionChecklistSheet", screenName: "Onboarding Permissions")
                checkInitialPermissions()
            }
        }
    }

    private func checkInitialPermissions() {
        let bluetoothManager = CBCentralManager(delegate: nil, queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if bluetoothManager.state == .poweredOn {
            }
        }

        if CMMotionActivityManager.isActivityAvailable() {
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.3)) {
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AnalyticsManager.shared.setUserProperty("true", forName: "finished_onboarding")
            AnalyticsManager.shared.logEvent("onboarding_completed")
            onComplete()
        }
    }
}
