#!/usr/bin/env swift

import Foundation

// Test the character normalization logic from the enhanced detection
func normalizeDeviceName(_ name: String) -> String {
    return name
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
}

// Test the pattern matching logic
func isAirPodsDevice(_ normalizedName: String) -> Bool {
    // Primary detection patterns - most common and reliable
    let primaryPatterns = [
        "airpods", "air pod", "airpod"
    ]

    // Secondary patterns for various models and variants
    let secondaryPatterns = [
        "airpods pro", "airpods max", "airpods 4", "airpods 3", "airpods 2",
        "airpods (1st generation)", "airpods (2nd generation)",
        "airpods (3rd generation)", "airpods (4th generation)", "airpods pro (2nd generation)"
    ]

    // Beats patterns that use Apple H1/H2 chips
    let beatsPatterns = [
        "beats studio buds", "beats fit pro", "beats studio pro",
        "beats solo pro", "powerbeats pro", "beats flex",
        "beats studio", "beats solo", "beats x", "powerbeats"
    ]

    let allPatterns = primaryPatterns + secondaryPatterns + beatsPatterns

    for pattern in allPatterns {
        if normalizedName.contains(pattern) {
            return true
        }
    }

    return false
}

// Test cases for problematic device names
let testCases = [
    // Original problematic cases
    "Sample AirPods",
    "José's AirPods Pro",
    "AirPods Pro\u{200B}", // Zero-width space
    "My Pro AirPods",

    // Edge cases with special characters
    "\"John's AirPods\"",
    "'Sarah's AirPods'",
    "AirPods™ Pro",
    "AirPods® Max",

    // International characters
    "Bjørn's AirPods",
    "Müller AirPods",
    "Łukasz's AirPods",
    "Émilie's AirPods Pro",

    // Invisible characters
    "AirPods\u{200D}Pro", // Zero-width joiner
    "AirPods\u{FEFF}", // Byte order mark
    "AirPods\u{200C}Max", // Zero-width non-joiner

    // Custom naming patterns
    "My Awesome AirPods",
    "Left AirPod",
    "Right AirPod Pro",
    "Work AirPods",

    // AirPods 4
    "AirPods 4",
    "My AirPods 4",
    "AirPods (4th generation)",
    "John's AirPods 4",

    // Beats devices
    "Beats Studio Pro",
    "Powerbeats Pro",
    "Beats Fit Pro",

    // Non-AirPods (should be false)
    "Sony WH-1000XM4",
    "Bose QuietComfort",
    "JBL Flip 6"
]

print("🧪 Testing Enhanced AirPods Detection Implementation")
print(String(repeating: "=", count: 60))

for (index, testName) in testCases.enumerated() {
    let normalizedName = normalizeDeviceName(testName)
    let isDetected = isAirPodsDevice(normalizedName)

    print("\(index + 1). Original: '\(testName)'")
    print("   Normalized: '\(normalizedName)'")
    print("   Detected: \(isDetected ? "✅ YES" : "❌ NO")")
    print()
}

print("📊 Test Summary")
print(String(repeating: "=", count: 60))

// Count results
let airpodsTestCases = testCases.filter { !$0.contains("Sony") && !$0.contains("Bose") && !$0.contains("JBL") }
let detectedCount = airpodsTestCases.filter { isAirPodsDevice(normalizeDeviceName($0)) }.count
let nonAirpodsTestCases = testCases.filter { $0.contains("Sony") || $0.contains("Bose") || $0.contains("JBL") }
let correctlyRejected = nonAirpodsTestCases.filter { !isAirPodsDevice(normalizeDeviceName($0)) }.count

print("AirPods/Beats test cases: \(airpodsTestCases.count)")
print("Successfully detected: \(detectedCount)")
print("Detection success rate: \(String(format: "%.1f", Double(detectedCount) / Double(airpodsTestCases.count) * 100))%")
print()
print("Non-AirPods test cases: \(nonAirpodsTestCases.count)")
print("Correctly rejected: \(correctlyRejected)")
print("Rejection accuracy: \(String(format: "%.1f", Double(correctlyRejected) / Double(nonAirpodsTestCases.count) * 100))%")

if detectedCount == airpodsTestCases.count && correctlyRejected == nonAirpodsTestCases.count {
    print("\n🎉 All tests passed! Enhanced detection working correctly.")
} else {
    print("\n⚠️ Some tests failed. Review the results above.")
}