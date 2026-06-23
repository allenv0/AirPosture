import Foundation

/// Owns delayed main-queue work so SwiftUI views can cancel pending callbacks on teardown.
final class DelayedTaskBag {
    private var workItems: [String: DispatchWorkItem] = [:]

    func schedule(id: String, after delay: TimeInterval, action: @escaping () -> Void) {
        cancel(id)

        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [weak self] in
            guard workItem?.isCancelled == false else { return }
            action()
            self?.workItems[id] = nil
        }

        guard let workItem else { return }
        workItems[id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancel(_ id: String) {
        workItems[id]?.cancel()
        workItems[id] = nil
    }

    func cancelAll() {
        workItems.values.forEach { $0.cancel() }
        workItems.removeAll()
    }

    deinit {
        cancelAll()
    }
}
