import SwiftUI
import CoreBluetooth
import CoreMotion
import os
#if os(iOS)
import UIKit
#endif

class BluetoothManagerDelegate: NSObject, CBCentralManagerDelegate {
    var isPoweredOn = false
    var isUnauthorized = false
    var onStateChange: ((Bool, Bool) -> Void)?

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let poweredOn = (central.state == .poweredOn)
        let unauthorized = (central.state == .unauthorized)

        if isPoweredOn != poweredOn || isUnauthorized != unauthorized {
            isPoweredOn = poweredOn
            isUnauthorized = unauthorized
            DispatchQueue.main.async {
                self.onStateChange?(poweredOn, unauthorized)
            }
        }
    }
}

struct PermissionChecklistSheet: View {
    @State private var bluetoothPermissionGranted = false
    @State private var motionPermissionGranted = false
    @State private var isAnimating = false
    @State private var bluetoothRequestInProgress = false
    @State private var motionRequestInProgress = false
    @State private var permissionMonitorTimer: Timer?
    @State private var uiUpdateTimer: Timer?
    @State private var permissionTimeoutTimer: Timer?
    @State private var showPermissionDeniedAlert = false

    @State private var cachedBluetoothManager: CBCentralManager?
    @State private var bluetoothDelegate: BluetoothManagerDelegate?

    let onComplete: () -> Void

    func updateBluetoothPermission(poweredOn: Bool, unauthorized: Bool) {
        if unauthorized {
            bluetoothRequestInProgress = false
        }
        bluetoothPermissionGranted = poweredOn && !unauthorized
    }

    private let buttonGradient: [Color] = [
        Color(red: 0.0, green: 0.4, blue: 1.0),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.6, blue: 0.9),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.4, blue: 1.0)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                    Image("bear-neck")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimating)

                        Text("Enable Permissions")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.8, blue: 1.0),
                                        Color(red: 0.3, green: 0.6, blue: 1.0),
                                        Color(red: 0.2, green: 0.4, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimating)

                        Text("We need access to connect your AirPods and track your posture")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: isAnimating)
                    }

                    VStack(spacing: 20) {
                        PermissionChecklistRow(
                            title: "Bluetooth",
                            description: "Connect to your AirPods",
                            iconName: "antenna.radiowaves.left.and.right",
                            isGranted: bluetoothPermissionGranted,
                            isInProgress: bluetoothRequestInProgress,
                            action: requestBluetoothPermission
                        )
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimating)

                        PermissionChecklistRow(
                            title: "Motion",
                            description: "Track head movement",
                            iconName: "figure.walk.motion",
                            isGranted: motionPermissionGranted,
                            isInProgress: motionRequestInProgress,
                            action: requestMotionPermission
                        )
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: isAnimating)
                    }

                    VStack(spacing: 8) {
                        Text("Device Support:")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("AirPods Pro (all models), AirPods (3rd gen+), AirPods Max. Beats earphones with spatial audio & dynamic head tracking.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.7), value: isAnimating)

                    Spacer()

                    Button(action: {
                        #if os(iOS)
                        HapticManager.shared.impact(style: .medium)
                        #endif
                        onComplete()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))

                            Text("Continue")
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
                                            colors: canContinue ? [
                                                Color(red: 0.2, green: 0.8, blue: 0.4),
                                                Color(red: 0.1, green: 0.6, blue: 0.3)
                                            ] : buttonGradient,
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
                                        colors: canContinue ? [
                                            Color.red.opacity(0.9),
                                            Color.orange.opacity(0.9),
                                            Color.yellow.opacity(0.9),
                                            Color.green.opacity(0.9),
                                            Color.blue.opacity(0.9),
                                            Color.indigo.opacity(0.9),
                                            Color.purple.opacity(0.9)
                                        ] : [
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
                        .shadow(color: (canContinue ? Color.green : Color.black).opacity(0.15), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1.0 : 0.6)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimating)
                    .animation(.easeInOut(duration: 0.15), value: canContinue)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }

            if cachedBluetoothManager == nil {
                bluetoothDelegate = BluetoothManagerDelegate()
                bluetoothDelegate?.onStateChange = { [self] poweredOn, unauthorized in
                    self.updateBluetoothPermission(poweredOn: poweredOn, unauthorized: unauthorized)
                }
                cachedBluetoothManager = CBCentralManager(delegate: bluetoothDelegate!, queue: .global(qos: .utility))
            }

            checkCurrentPermissions()

            startPermissionMonitoring()

            startPermissionTimeout()
        }
        .onDisappear {
            stopPermissionMonitoring()

            cachedBluetoothManager = nil
        }
    }

    private var canContinue: Bool {
        bluetoothPermissionGranted && motionPermissionGranted
    }

    private func checkCurrentPermissions() {
        DispatchQueue.global(qos: .userInteractive).async {
            let previousBluetooth = self.bluetoothPermissionGranted
            let previousMotion = self.motionPermissionGranted

            var bluetoothGranted = false
            var motionGranted = false

            if let manager = self.cachedBluetoothManager {
                let state = manager.state
                bluetoothGranted = (state == .poweredOn) && (state != .unauthorized)
                if state == .unauthorized {
                    DispatchQueue.main.async {
                        self.bluetoothRequestInProgress = false
                    }
                }
            } else if let delegate = self.bluetoothDelegate, delegate.isPoweredOn && !delegate.isUnauthorized {
                bluetoothGranted = delegate.isPoweredOn && !delegate.isUnauthorized
            }

            motionGranted = CMMotionActivityManager.isActivityAvailable()

            let bluetoothChanged = previousBluetooth != bluetoothGranted
            let motionChanged = previousMotion != motionGranted

            if bluetoothChanged || motionChanged {
                self.updatePermissionStates(bluetoothGranted: bluetoothGranted, motionGranted: motionGranted)
            }
        }
    }

    private func updatePermissionStates(bluetoothGranted: Bool, motionGranted: Bool) {
        uiUpdateTimer?.invalidate()

        DispatchQueue.main.async {
            self.uiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { _ in
                let bluetoothChanged = self.bluetoothPermissionGranted != bluetoothGranted
                let motionChanged = self.motionPermissionGranted != motionGranted

                if bluetoothChanged {
                    self.bluetoothPermissionGranted = bluetoothGranted
                }
                if motionChanged {
                    self.motionPermissionGranted = motionGranted
                }

                if bluetoothGranted && motionGranted {
                    bluetoothRequestInProgress = false
                    motionRequestInProgress = false
                    self.switchToSlowMonitoring()
                }

                self.uiUpdateTimer = nil
            }
        }
    }

    private func startPermissionMonitoring() {
        DispatchQueue.main.async {
            self.startAggressiveMonitoring()
        }
    }

    private func startAggressiveMonitoring() {
        if self.permissionMonitorTimer != nil {
            return
        }

        self.permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            self.checkCurrentPermissions()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.switchToSlowMonitoring()
        }
    }

    private func switchToSlowMonitoring() {
        self.permissionMonitorTimer?.invalidate()

        DispatchQueue.main.async {
            self.permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self.checkCurrentPermissions()
            }
        }
    }

    private func stopPermissionMonitoring() {
        Logger.general.debug("Stopping permission monitoring immediately")

        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
        uiUpdateTimer?.invalidate()
        uiUpdateTimer = nil
        permissionTimeoutTimer?.invalidate()
        permissionTimeoutTimer = nil

        bluetoothRequestInProgress = false
        motionRequestInProgress = false

        Logger.general.debug("Permission monitoring stopped completely")
    }

    private func startPermissionTimeout() {
        DispatchQueue.main.async {
            self.permissionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
                if !self.bluetoothPermissionGranted || !self.motionPermissionGranted {
                    self.bluetoothRequestInProgress = false
                    self.motionRequestInProgress = false
                }
                self.permissionTimeoutTimer = nil
            }
        }
    }

    private func requestBluetoothPermission() {
        bluetoothRequestInProgress = true

        if let manager = cachedBluetoothManager {
            if manager.state == .poweredOn {
                DispatchQueue.main.async {
                    self.bluetoothPermissionGranted = true
                }
            }
        }

        checkCurrentPermissions()

        for i in 1...10 {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + Double(i) * 0.5) {
                self.checkCurrentPermissions()
            }
        }
    }

    private func requestMotionPermission() {
        motionRequestInProgress = true

        DispatchQueue.global(qos: .userInteractive).async {
            let manager = CMMotionManager()
            manager.deviceMotionUpdateInterval = 1.0

            manager.startDeviceMotionUpdates()
            manager.stopDeviceMotionUpdates()

            self.checkCurrentPermissions()

            for i in 1...8 {
                DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + Double(i) * 0.4) {
                    self.checkCurrentPermissions()
                }
            }
        }
    }
}

struct PermissionChecklistRow: View {
    let title: String
    let description: String
    let iconName: String
    let isGranted: Bool
    let isInProgress: Bool
    let action: () -> Void

    private let startButtonGradientSmall: [Color] = [
        Color(red: 0.0, green: 0.4, blue: 1.0),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.6, blue: 0.9),
        Color(red: 0.0, green: 0.5, blue: 0.95),
        Color(red: 0.0, green: 0.4, blue: 1.0)
    ]

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        isGranted ?
                        LinearGradient(colors: startButtonGradientSmall, startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isGranted ? .white : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.green)
            } else if isInProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: startButtonGradientSmall.first ?? .blue))
                    .scaleEffect(0.8)
            } else {
                Text("Allow")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: startButtonGradientSmall,
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
                                    lineWidth: 1.0
                                )
                                .padding(0.5)

                            Capsule()
                                .stroke(
                                    Color.black.opacity(0.25),
                                    lineWidth: 1.0
                                )
                        }
                    )
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.7),
                                        Color.orange.opacity(0.7),
                                        Color.yellow.opacity(0.7),
                                        Color.green.opacity(0.7),
                                        Color.blue.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blur(radius: 6)
                            .offset(y: 3)
                            .scaleEffect(1.0)
                            .opacity(0.6)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                    .onTapGesture {
                        #if os(iOS)
                        HapticManager.shared.impact(style: .light)
                        #endif
                        action()
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}
