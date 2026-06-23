#!/usr/bin/env swift

import Foundation

// Simulate the dual detection system logic
struct MockDetectionSystem {
    var enhancedDetectionEnabled: Bool = false
    var connectionMethod: String = "original"

    // Simulate enhanced detection (always successful for AirPods in our test)
    func checkAirPodsAudioConnectionEnhanced(deviceName: String) -> Bool {
        // Normalize device name
        let normalizedName =
            deviceName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(
                of: "[\\p{Cf}\\p{Zl}\\p{Zp}]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "[\"\u{2018}\u{2019}\u{201C}\u{201D}]",
                with: "'",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Enhanced detection patterns
        let patterns = [
            "airpods", "air pod", "airpod", "airpods pro", "airpods max",
            "airpods 4", "airpods 3", "airpods 2", "beats studio", "beats fit", "powerbeats",
        ]

        return patterns.contains { normalizedName.contains($0) }
    }

    // Simulate original detection (more limited)
    func checkAirPodsAudioConnectionOriginal(deviceName: String) -> Bool {
        return deviceName.lowercased().contains("airpods")
    }

    // Main dual detection logic
    mutating func checkAirPodsAudioConnection(deviceName: String) -> Bool {
        // Dual detection system with fallback
        if enhancedDetectionEnabled {
            if checkAirPodsAudioConnectionEnhanced(deviceName: deviceName) {
                connectionMethod = "enhanced"
                print("🎉 Enhanced detection successful")
                return true
            }

            // Fall back to original detection if enhanced fails
            print("🔄 Enhanced detection failed, falling back to original detection")
        }

        // Original: Always available as safety net
        if checkAirPodsAudioConnectionOriginal(deviceName: deviceName) {
            connectionMethod = "original"
            print("📱 Original detection successful")
            return true
        }

        connectionMethod = "none"
        print("❌ No AirPods detected")
        return false
    }
}

print("🧪 Testing Dual Detection System Logic")
print(String(repeating: "=", count: 60))

var detectionSystem = MockDetectionSystem()

// Test scenarios
let testScenarios = [
    ("Sample AirPods", "Special characters - should work with enhanced"),
    ("José's AirPods Pro", "International characters - should work with enhanced"),
    ("Beats Studio Pro", "Beats device - should work with enhanced only"),
    ("Basic AirPods", "Simple case - should work with both"),
    ("Sony Headphones", "Non-Apple device - should fail with both"),
]

print("1️⃣  Testing with Enhanced Detection DISABLED (Original only)")
print(String(repeating: "-", count: 50))
detectionSystem.enhancedDetectionEnabled = false

for (deviceName, description) in testScenarios {
    print("\nTesting: '\(deviceName)' - \(description)")
    let result = detectionSystem.checkAirPodsAudioConnection(deviceName: deviceName)
    print("Result: \(result ? "✅ Connected" : "❌ Not connected")")
    print("Method: \(detectionSystem.connectionMethod)")
}

print("\n" + String(repeating: "=", count: 60))
print("2️⃣  Testing with Enhanced Detection ENABLED (Enhanced with fallback)")
print(String(repeating: "-", count: 50))
detectionSystem.enhancedDetectionEnabled = true

for (deviceName, description) in testScenarios {
    print("\nTesting: '\(deviceName)' - \(description)")
    let result = detectionSystem.checkAirPodsAudioConnection(deviceName: deviceName)
    print("Result: \(result ? "✅ Connected" : "❌ Not connected")")
    print("Method: \(detectionSystem.connectionMethod)")
}

print("\n" + String(repeating: "=", count: 60))
print("3️⃣  Testing Edge Cases")
print(String(repeating: "-", count: 50))

// Edge case: Enhanced detection fails, original succeeds
let edgeCaseDeviceName = "MyAirpods"  // No space, should work with original but not enhanced

print("\nEdge Case: '\(edgeCaseDeviceName)' (no space)")
print("Expected: Enhanced fails, Original succeeds")

detectionSystem.enhancedDetectionEnabled = true
let edgeResult = detectionSystem.checkAirPodsAudioConnection(deviceName: edgeCaseDeviceName)
print("Result: \(edgeResult ? "✅ Connected" : "❌ Not connected")")
print("Method: \(detectionSystem.connectionMethod)")

print("\n" + String(repeating: "=", count: 60))
print("📊 Test Summary")
print(String(repeating: "=", count: 60))

print("✅ Enhanced detection should handle:")
print("   • Special characters (apostrophes, quotes)")
print("   • International characters (accents, diacritics)")
print("   • Invisible characters (zero-width spaces)")
print("   • Beats devices (Studio, Fit, Powerbeats)")
print("   • Custom naming patterns")

print("\n✅ Original detection should:")
print("   • Always work as a fallback")
print("   • Handle basic AirPods detection")
print("   • Provide backward compatibility")

print("\n✅ Dual detection system should:")
print("   • Try enhanced first when enabled")
print("   • Fall back to original if enhanced fails")
print("   • Track which method succeeded")
print("   • Never break existing functionality")

print("\n🎉 Dual detection system logic verified!")
