import Testing
import Foundation
@testable import AirPosture

@Suite("DelayedTaskBag Tests")
struct DelayedTaskBagTests {

    @Test("Task bag starts empty")
    func testInitialState() {
        let bag = DelayedTaskBag()
        bag.schedule(id: "test", after: 60) {}
        bag.cancel("test")
    }

    @Test("Scheduled task fires after delay")
    func testTaskFires() async throws {
        let bag = DelayedTaskBag()
        let didFire = Locked(false)

        bag.schedule(id: "test", after: 0.01) {
            didFire.value = true
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(didFire.value)
    }

    @Test("Cancelled task does not fire")
    func testCancelledTaskDoesNotFire() async throws {
        let bag = DelayedTaskBag()
        let didFire = Locked(false)

        bag.schedule(id: "test", after: 0.05) {
            didFire.value = true
        }
        bag.cancel("test")

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!didFire.value)
    }

    @Test("Cancel all prevents all tasks from firing")
    func testCancelAll() async throws {
        let bag = DelayedTaskBag()
        let task1Fired = Locked(false)
        let task2Fired = Locked(false)

        bag.schedule(id: "task1", after: 0.05) { task1Fired.value = true }
        bag.schedule(id: "task2", after: 0.05) { task2Fired.value = true }
        bag.cancelAll()

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!task1Fired.value)
        #expect(!task2Fired.value)
    }

    @Test("Rescheduling same id replaces previous task")
    func testReschedulingReplaces() async throws {
        let bag = DelayedTaskBag()
        let firedValue = Locked("initial")

        bag.schedule(id: "test", after: 0.05) { firedValue.value = "old" }
        bag.schedule(id: "test", after: 0.01) { firedValue.value = "new" }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(firedValue.value == "new")
    }

    @Test("Multiple tasks with different IDs all fire")
    func testMultipleTasks() async throws {
        let bag = DelayedTaskBag()
        let results = Locked(Set<String>())

        bag.schedule(id: "a", after: 0.01) { results.value.insert("a") }
        bag.schedule(id: "b", after: 0.01) { results.value.insert("b") }
        bag.schedule(id: "c", after: 0.01) { results.value.insert("c") }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(results.value == ["a", "b", "c"])
    }
}

/// Simple thread-safe mutable container for testing async state.
private final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
    private var _value: T

    init(_ value: T) {
        _value = value
    }
}
