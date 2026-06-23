import Testing
import SwiftUI
@testable import AirPosture

@Suite("PostureColors")
struct PostureColorsTests {
    @Test("Good posture percentage returns good color")
    func testGoodPostureColor() {
        let color = PostureColors.forPosturePercentage(80)
        #expect(color == PostureColors.good)
    }
    
    @Test("Warning posture percentage returns warning color")
    func testWarningPostureColor() {
        let color = PostureColors.forPosturePercentage(50)
        #expect(color == PostureColors.warning)
    }
    
    @Test("Poor posture percentage returns poor color")
    func testPoorPostureColor() {
        let color = PostureColors.forPosturePercentage(30)
        #expect(color == PostureColors.poor)
    }
    
    @Test("Boundary at 60 percent returns good color")
    func testBoundary60() {
        let color = PostureColors.forPosturePercentage(60)
        #expect(color == PostureColors.good)
    }
    
    @Test("Boundary at 40 percent returns warning color")
    func testBoundary40() {
        let color = PostureColors.forPosturePercentage(40)
        #expect(color == PostureColors.warning)
    }
    
    @Test("Zero percent returns poor color")
    func testZeroPercent() {
        let color = PostureColors.forPosturePercentage(0)
        #expect(color == PostureColors.poor)
    }
}
