#if os(iOS)
import UIKit
#endif
import SwiftUI
import os

struct PostureHomeView: View {
    @State private var headphoneMotionManager = HeadphoneMotionManager.shared
    @ObservedObject private var sessionStore = SessionStore.shared
    @State private var themeManager = ThemeManager.shared
    @State private var avatarManager = AvatarManager.shared
    @State private var viewModel: PostureHomeViewModel

    #if os(iOS)
    init() {
        _viewModel = State(wrappedValue: PostureHomeViewModel(
            motionManager: HeadphoneMotionManager.shared,
            sessionStore: SessionStore.shared,
            bluetoothManager: BluetoothManager()
        ))
    }
    #else
    init() {
        _viewModel = State(wrappedValue: PostureHomeViewModel(
            motionManager: HeadphoneMotionManager.shared,
            sessionStore: SessionStore.shared
        ))
    }
    #endif
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }


    
    private func isLargeScreen(_ geometry: GeometryProxy) -> Bool {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return geometry.size.width >= 430
        #elseif os(macOS)
        return geometry.size.width > 600
        #else
        return geometry.size.width > 600
        #endif
    }
    
    private func getCircleSizes(for screenWidth: CGFloat) -> (bear: CGFloat, posture: CGFloat) {
        let circleSize: CGFloat
        if screenWidth >= 430 {
            circleSize = screenWidth * 0.33 * 1.10
        } else if screenWidth >= 393 {
            circleSize = screenWidth * 0.29 * 1.10
        } else {
            circleSize = screenWidth * 0.26 * 1.10
        }
        return (bear: circleSize, posture: circleSize)
    }
    
    private var sortedSessionsAscending: [Session] {
        sessionStore.sessions.sorted { $0.startTime < $1.startTime }
    }
    
    private var sortedSessionsDescending: [Session] {
        sessionStore.sessions.sorted { $0.startTime > $1.startTime }
    }
    
    @ViewBuilder
    private func postureModeContent(geometry: GeometryProxy) -> some View {
        let (bearSize, postureSize) = getCircleSizes(for: geometry.size.width)
        let totalWidth = bearSize + postureSize
        let gap: CGFloat = 22
        
        VStack(spacing: 16) {
            HStack(spacing: gap) {
                HeadVisualization(
                    pitch: headphoneMotionManager.pitch,
                    roll: headphoneMotionManager.roll,
                    yaw: headphoneMotionManager.yaw,
                    postureState: headphoneMotionManager.postureState,
                    screenWidth: geometry.size.width,
                    colorScheme: colorScheme,
                    currentAvatar: avatarManager.selectedAvatar,
                    onAvatarTap: {
                        #if os(iOS)
                        HapticManager.shared.impact(style: .light)
                        #endif
                        avatarManager.selectedAvatar = avatarManager.selectedAvatar.next
                    },
                    size: bearSize,
                    poorPostureThreshold: headphoneMotionManager.poorPostureThreshold,
                    normalAirPodsAngle: headphoneMotionManager.normalAirPodsAngle,
                    isUserRunningOrWalking: headphoneMotionManager.isUserRunningOrWalking
                )
                .frame(width: bearSize, height: bearSize)
                
                PercentageCircle(
                    percentage: headphoneMotionManager.postureScorePercent,
                    size: postureSize,
                    title: "Good Posture",
                    isPad: isLargeScreen(geometry),
                    colorScheme: colorScheme,
                    isAnimatingLogo: false
                )
                .frame(width: postureSize, height: postureSize)
            }
            .frame(width: totalWidth, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.top, 90)
            .padding(.bottom, 50)
            
            ControlButtons(
                isPaused: headphoneMotionManager.isPaused,
                isDeviceConnected: headphoneMotionManager.isDeviceConnected,
                isAnimatingLogo: false,
                onPause: {
                    viewModel.togglePause()
                },
                onStop: {
                    viewModel.stopSession()
                },
                onReconnect: {
                    viewModel.reconnect()
                },
                colorScheme: colorScheme
            )
            .padding(.bottom, 30)
            
            PitchGraphView(
                dataPoints: headphoneMotionManager.pitchHistory,
                currentPitch: headphoneMotionManager.pitch,
                poorPostureDuration: headphoneMotionManager.poorPostureDuration,
                postureScorePercent: headphoneMotionManager.postureScorePercent,
                totalSessionTime: headphoneMotionManager.totalSessionTime,
                screenWidth: geometry.size.width,
                threshold: headphoneMotionManager.poorPostureThreshold,
                normalAirPodsAngle: headphoneMotionManager.normalAirPodsAngle,
                colorScheme: colorScheme,
                isAnimatingLogo: false
            )
        }
    }
    
    private     var screenWidth: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width
        #else
        return 800
        #endif
    }

    var body: some View {
        postureTabContent
    }

    @ViewBuilder
    private var postureTabContent: some View {
        @Bindable var vm = viewModel
        GeometryReader { geometry in
                ZStack {
                    backgroundColor
                        .ignoresSafeArea()
                    
                    if headphoneMotionManager.isDeviceConnected && sessionStore.currentSession != nil {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            VStack(spacing: 8) {
                                if headphoneMotionManager.sessionPaused {
                                    ConnectionStatusBanner(
                                        isInGracePeriod: headphoneMotionManager.isInGracePeriod,
                                        connectionStatus: headphoneMotionManager.connectionStatus
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                }
                                




                                if headphoneMotionManager.hapticController.isInWarningCountdown {
                                    PostureWarningBanner(
                                        warningCountdownSeconds: headphoneMotionManager.hapticController.warningCountdownSeconds,
                                        colorScheme: colorScheme
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: headphoneMotionManager.hapticController.isInWarningCountdown)
                                }

                                if headphoneMotionManager.hapticController.isInRecoveryCountdown {
                                    PostureRecoveryBanner(
                                        recoveryCountdownSeconds: headphoneMotionManager.hapticController.recoveryCountdownSeconds,
                                        colorScheme: colorScheme
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: headphoneMotionManager.hapticController.isInRecoveryCountdown)
                                }
                                
                                postureModeContent(geometry: geometry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onDisappear {
                        viewModel.tearDownTransientConnectionUI()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(minHeight: 50)
                            
                            VStack(spacing: 40) {
                            Group {
                                #if os(macOS)
                                let avatarName = AvatarManager.shared.selectedAvatar.rawValue
                                if Bundle.main.path(forResource: avatarName, ofType: nil) != nil {
                                    Image(avatarName)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 60))
                                }
                                #else
                                Image(AvatarManager.shared.selectedAvatar.rawValue)
                                    .resizable()
                                    .scaledToFit()
                                #endif
                            }
                            .background(
                                StaticOrbitBackground()
                            )
                            .frame(width: 84, height: 84)
                            .foregroundColor(.blue)
                            .shadow(
                                color: .white.opacity(0.3),
                                radius: 6,
                                x: 2,
                                y: 4
                            )
                            .shadow(
                                color: .blue.opacity(0.2),
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                            
                            Text("AirPosture")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                                .multilineTextAlignment(.center)
                            
                            let lastSessionPercentage = sortedSessionsAscending.last?.poorPosturePercentage ?? 0
                            
                            PercentageCircle(
                                percentage: lastSessionPercentage,
                                size: isLargeScreen(geometry) ? 182 : 118,
                                title: "Last Session",
                                isPad: isLargeScreen(geometry),
                                shouldAnimate: false,
                                colorScheme: colorScheme,
                                isAnimatingLogo: false
                            )
                            
                            VStack(spacing: 12) {
                                if headphoneMotionManager.isInGracePeriod {
                                    Text("Bluetooth Connection Lost")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    
                                    Text("Attempting to reconnect to AirPods...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                } else {
                                    VStack(spacing: 20) {
                                        if viewModel.startButtonState == .connecting || viewModel.startButtonState == .retrying || viewModel.startButtonState == .error {
                                            ConnectionAnimationView(startButtonState: viewModel.startButtonState)
                                                .frame(height: 80)
                                                .padding(.bottom, 8)
                                        }
                                        
                                        Button(action: {
                                            viewModel.handleStartButtonPressed()
                                        }) {
                                            VStack(spacing: 4) {
                                                Text(viewModel.startButtonState.title)
                                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                
                                                if viewModel.startButtonState == .connecting || viewModel.startButtonState == .retrying || viewModel.startButtonState == .error {
                                                    MinimalProgressBar(
                                                        progress: viewModel.connectionProgress,
                                                        isVisible: true
                                                    )
                                                    .frame(height: 20)
                                                }
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
                                                .padding(.horizontal,46)
                                                .padding(.vertical, 14)
                                                .background(
                                                    ZStack {
                                                         Capsule()
                                                             .fill(
                                                                 LinearGradient(
                                                                     colors: [
                                                                         Color(red: 0.0, green: 0.38, blue: 0.95),
                                                                         Color(red: 0.0, green: 0.475, blue: 0.9025),
                                                                         Color(red: 0.0, green: 0.57, blue: 0.855),
                                                                         Color(red: 0.0, green: 0.475, blue: 0.9025),
                                                                         Color(red: 0.0, green: 0.38, blue: 0.95)
                                                                     ],
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
                                                        .scaleEffect(1.0)
                                                        .opacity(0.8)
                                                )
                                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        }
                                        .frame(maxWidth: 312)
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.startButtonState.isInteractionBlocked)
                                        .accessibilityLabel(viewModel.startButtonState.title)
                                        .accessibilityValue(viewModel.startButtonState.accessibilityValue)
                                        .accessibilityHint("Starts posture tracking with compatible AirPods.")
                                        .scaleEffect(viewModel.isSmartButtonPressed ? 0.98 : 1.0)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isSmartButtonPressed)
                                        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                viewModel.isSmartButtonPressed = pressing
                                            }
                                        }, perform: {})

                                        if viewModel.startButtonState == .retrying {
                                            HStack {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundColor(.orange)

                                                Text("Auto-retrying in \(viewModel.retryCountdown) seconds...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.orange.opacity(0.1))
                                            )
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.3), value: viewModel.startButtonState)
                                        }

                                        if headphoneMotionManager.isDeviceConnected {
                                            ConnectedDeviceInfoView(
                                                isConnected: headphoneMotionManager.isDeviceConnected,
                                                hasMotionCapability: headphoneMotionManager.hasMotionCapability,
                                                connectedDeviceName: headphoneMotionManager.connectedDeviceName,
                                                colorScheme: colorScheme
                                            )
                                            .padding(.horizontal, 8)
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                                removal: .opacity
                                            ))
                                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: headphoneMotionManager.isDeviceConnected)
                                        }
                                   
                                         Spacer()
                                            .frame(height: 10)

                                        if !sessionStore.sessions.isEmpty || sessionStore.isShowingDemoSessions {
                                            let latestFiveSessions = Array(sortedSessionsDescending.prefix(5))

                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Latest Sessions")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(primaryTextColor)
                                                    .padding(.horizontal, 4)

                                                VStack(spacing: 8) {
                                                    ForEach(latestFiveSessions) { session in
                                                        LatestSessionRow(
                                                            session: session,
                                                            colorScheme: colorScheme,
                                                            primaryTextColor: primaryTextColor,
                                                            secondaryTextColor: SettingsColors.secondaryText(for: colorScheme),
                                                            cardBackgroundColor: cardBackgroundColor,
                                                            cardShadowColor: cardShadowColor
                                                        )
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }

                                        Spacer()
                                            .frame(height: 15)

                                      }
                                }

                            }
                            .padding(.bottom, 5)
                            
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                            .frame(minHeight: 50)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
            .onAppear {
                viewModel.handleInitialAppearance()
            }
            .onChange(of: sessionStore.sessions) {
                Logger.session.debug("Sessions changed - Current count: \(sessionStore.sessions.count)")
                if let lastSession = sessionStore.sessions.first {
                    Logger.session.debug("Last session duration: \(lastSession.totalDuration) seconds")
                }
            }
            .alert("Bluetooth Connection Lost", isPresented: $headphoneMotionManager.showConnectionLostAlert) {
                Button("OK") {
                    headphoneMotionManager.dismissConnectionAlert()
                }
            } message: {
                Text("Your AirPods connection was lost. Your current session was saved.")
            }
            .sheet(isPresented: $vm.showSettingsSheet) {
                SettingsSheet(
                    selectedTab: $vm.selectedSettingsTab,
                    currentAvatar: $avatarManager.selectedAvatar,
                    colorScheme: colorScheme,
                    motionManager: headphoneMotionManager,
                    sessionStore: sessionStore
                )
            }
            .onChange(of: viewModel.showSettingsSheet) { _, newValue in
                viewModel.handleSettingsSheetChange(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AirPodsConnected"))) { _ in
                viewModel.handleAirPodsConnectedNotification()
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.handleAppBecameActive()
            }
            #endif

            .onChange(of: headphoneMotionManager.isDeviceConnected) { _, isConnected in
                viewModel.handleConnectionStateChanged(isConnected: isConnected)
            }

            if viewModel.showAirPodsDropdown {
                AirPodsDropdownOverlay(
                    isVisible: $vm.showAirPodsDropdown,
                    onDropdownComplete: {
                        viewModel.handleAirPodsDropdownComplete()
                    }
                )
            }
        }
        .onAppear {
            #if os(iOS)
            viewModel.setupBluetoothCallbacks()
            #endif
        }
        .onDisappear {
            viewModel.tearDownTransientConnectionUI()
        }
    }
}
