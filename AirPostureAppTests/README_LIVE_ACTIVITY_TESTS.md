# Live Activity Tests Guide

This guide explains the comprehensive test suite for the AirPosture Live Activity and Dynamic Island feature.

## 📋 Test Files Created

Three comprehensive test files have been created:

### 1. **LiveActivityTests.swift**
Location: `/AirPostureAppTests/LiveActivityTests.swift`

**What it tests:**
- ✅ Color system calculations (good/caution/poor posture colors)
- ✅ Data model initialization and correctness
- ✅ PostureStatus enum values and encoding
- ✅ ActivityAttributes metadata
- ✅ Image loading for bear-avatars asset
- ✅ Rotation calculations (pitch/roll to degrees)
- ✅ Progress ring trim values
- ✅ Color palette validation
- ✅ Session timer formatting
- ✅ Edge cases (zero rotation, extreme values, boundaries)

**Test Count:** ~20 unit tests

### 2. **WidgetSnapshotTests.swift**
Location: `/AirPostureAppTests/WidgetSnapshotTests.swift`

**What it tests:**
- ✅ Widget UI states (good/caution/poor posture)
- ✅ Head rotation data handling
- ✅ Session timer display
- ✅ Progress ring calculations
- ✅ Avatar asset loading
- ✅ Edge cases (min/max percentages, equal split)
- ✅ State transitions (good → poor, multiple updates)
- ✅ Unknown status handling
- ✅ Data consistency (good + poor = 100%)
- ✅ Session metadata (UUID, username, avatar)

**Test Count:** ~20 UI tests

### 3. **LiveActivityIntegrationTests.swift**
Location: `/AirPostureAppTests/LiveActivityIntegrationTests.swift`

**What it tests:**
- ✅ ActivityAuthorizationInfo checks
- ✅ LiveActivityController singleton
- ✅ Start/Update/End operations
- ✅ Update throttling
- ✅ Motion data flow
- ✅ Percentage calculations
- ✅ Posture status mapping
- ✅ Timer formatting
- ✅ Extreme values handling
- ✅ Rapid status changes
- ✅ Memory management (multiple sessions)
- ✅ Error handling (nil parameters, invalid percentages)
- ✅ Concurrent updates
- ✅ Performance benchmarks

**Test Count:** ~15 integration tests

---

## 🚀 How to Run the Tests

### **Option 1: Using Xcode (Recommended)**

1. **Open the project in Xcode**
   ```bash
   open AirPosture.xcodeproj
   ```

2. **Add test target to scheme** (if not already configured):
   - Click on the "AirPosture" scheme in the toolbar
   - Select "Edit Scheme..."
   - Go to the "Test" tab
   - Click "+" to add tests
   - Check the boxes next to:
     - `LiveActivityTests`
     - `WidgetSnapshotTests`
     - `LiveActivityIntegrationTests`

3. **Run tests**:
   - Press `Cmd + U` to run all tests
   - Or right-click on a specific test file and select "Run [Test Name]"
   - Or click the diamond next to each test to run individually

### **Option 2: Using Command Line**

```bash
# Run all tests
xcodebuild test -scheme AirPosture -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test suite
xcodebuild test -scheme AirPosture -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:AirPostureAppTests/LiveActivityTests

# Run specific test
xcodebuild test -scheme AirPosture -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:AirPostureAppTests/LiveActivityTests/testGoodPostureColor
```

---

## 📊 Test Coverage

The test suite covers:

### **Unit Tests (~20 tests)**
- Color calculations and palette validation
- Data model correctness
- Image asset loading
- Rotation mathematics
- Progress ring logic
- Timer formatting

### **UI Tests (~20 tests)**
- Widget state rendering
- Avatar display
- Motion data visualization
- Progress indicators
- Status badges
- Edge case UI handling

### **Integration Tests (~15 tests)**
- Full Live Activity lifecycle
- Controller behavior
- Data flow from sensors to widget
- Memory management
- Performance benchmarks
- Error handling
- Concurrency

**Total: ~55 tests**

---

## 🔍 What's Being Tested

### **Critical User Flows**
1. ✅ Starting a posture tracking session
2. ✅ Updating Live Activity with motion data
3. ✅ Displaying correct posture status (good/caution/poor)
4. ✅ Rotating bear avatar with head movement
5. ✅ Showing accurate posture percentages
6. ✅ Ending a session

### **Premium Design System**
1. ✅ Color coding (>70% green, 30-70% amber, <30% red)
2. ✅ Motion accent colors (cyan #00BFFF)
3. ✅ Progress ring gradients
4. ✅ Smooth rotation animations
5. ✅ Premium dark backgrounds

### **Edge Cases**
1. ✅ Zero/Extreme rotation values
2. ✅ Boundary percentages (exactly 70%, 30%)
3. ✅ Rapid status changes
4. ✅ Concurrent updates
5. ✅ Nil/Invalid parameters
6. ✅ Unknown status

---

## 🐛 Debugging Failed Tests

### **View Test Results in Xcode**
1. Open the Test Navigator (`Cmd + 6`)
2. Failed tests show red diamonds
3. Click on a failed test to see:
   - Error message
   - Expected vs actual values
   - Stack trace

### **Common Issues**

**Issue:** "bear-avatars image not found"
**Solution:** In test environment, assets may not be loaded. Tests handle this gracefully by checking if we're in XCTest environment.

**Issue:** "Live Activities not authorized"
**Solution:** Expected in test environment. The controller should handle authorization failures gracefully.

**Issue:** Tests timing out
**Solution:** Some tests perform 100 updates for performance testing. Increase timeout or reduce iteration count.

---

## ✅ Test Checklist

Before releasing, ensure:

- [ ] All unit tests pass
- [ ] All UI tests pass
- [ ] All integration tests pass
- [ ] Performance tests complete in < 1 second
- [ ] No memory leaks in multiple session test
- [ ] Color calculations match design spec
- [ ] Avatar loads correctly in all states
- [ ] Rotation responds to pitch/roll correctly
- [ ] Progress ring animates smoothly
- [ ] Timer formats correctly

---

## 📈 Adding New Tests

To add a new test:

```swift
@Test("Descriptive test name") func testFeature() async throws {
    // Arrange
    let input = "test value"

    // Act
    let result = process(input)

    // Assert
    #expect(result == "expected value")
}
```

### **Best Practices**
1. **One assertion per test** (when possible)
2. **Descriptive test names** that explain what is being tested
3. **Test edge cases** alongside happy paths
4. **Use async/await** for asynchronous operations
5. **Group related tests** using `@Suite`

---

## 🎯 Future Test Enhancements

Consider adding:

1. **UI Snapshot Tests** - Capture widget screenshots and compare with reference images
2. **Accessibility Tests** - Verify VoiceOver labels and contrast ratios
3. **Performance Monitoring** - Track Live Activity launch and update times
4. **Network Tests** - Test push notification updates (if implemented)
5. **Localization Tests** - Test with different languages/regions

---

## 📞 Troubleshooting

**Tests not showing in Xcode?**
- Ensure test files are added to the test target
- Clean build folder (`Cmd + Shift + K`)
- Restart Xcode

**Tests failing on CI but passing locally?**
- Check iOS Simulator version
- Verify all assets are included in test target
- Check entitlements and provisioning profiles

**Slow test execution?**
- Run tests in parallel using `-parallel-testing`
- Use `-only-testing` to run specific tests during development

---

## 📚 Additional Resources

- [Apple's Testing Documentation](https://developer.apple.com/documentation/xcode/testing)
- [Swift Testing Framework](https://developer.apple.com/documentation/testing)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)

---

**Created:** January 20, 2026
**Test Framework:** Swift Testing (iOS 18+)
**Total Tests:** ~55
**Coverage:** Live Activity, Dynamic Island, Color System, Data Flow
