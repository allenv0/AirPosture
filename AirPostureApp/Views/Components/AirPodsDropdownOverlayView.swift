import SwiftUI

struct AirPodsDropdownOverlay: View {
    @Binding var isVisible: Bool
    let onDropdownComplete: () -> Void
    @State private var dropdownOffset: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var hasTriggeredCallback = false
    @State private var delayedTasks = DelayedTaskBag()

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture {
                    dismissDropdown()
                }

            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                        .accessibilityHidden(true)

                    Text("1. Tap iPhone Speaker 👇 2. Tap Your AirPods")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .opacity(0.6)
                            .accessibilityHidden(true)

                        Text("Looking for AirPods...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.4, blue: 1.0),
                                        Color(red: 0.0, green: 0.5, blue: 0.95),
                                        Color(red: 0.0, green: 0.6, blue: 0.9),
                                        Color(red: 0.0, green: 0.5, blue: 0.95),
                                        Color(red: 0.0, green: 0.4, blue: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)

                        RoundedRectangle(cornerRadius: 20)
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

                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                Color.black.opacity(0.25),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .background(
                    RoundedRectangle(cornerRadius: 20)
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
                        .scaleEffect(pulseScale > 1.05 ? 1.05 : 1.0)
                        .opacity(pulseScale > 1.05 ? 0.8 : 0.8)
                )
            }
            .scaleEffect(0.7)
            .offset(y: dropdownOffset)
            .opacity(opacity)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Connect AirPods")
            .accessibilityValue("Tap iPhone Speaker, then tap your AirPods. Looking for AirPods.")
            .accessibilityHint("Double tap outside this prompt to dismiss it.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                dropdownOffset = 0
                opacity = 1.0
            }

            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        .onChange(of: isVisible) { newValue in
            if !newValue {
                dismissDropdown()
            }
        }
        .onDisappear {
            delayedTasks.cancelAll()
        }
    }

    private func dismissDropdown() {
        guard !hasTriggeredCallback else { return }
        hasTriggeredCallback = true

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            dropdownOffset = -100
            opacity = 0
        }

        delayedTasks.schedule(id: "dismissDropdown", after: 0.3) {
            onDropdownComplete()
            isVisible = false
        }
    }
}
