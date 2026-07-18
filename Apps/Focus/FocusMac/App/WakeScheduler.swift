import Foundation

/// Owns the single next-deadline wake task for the session runtime.
actor WakeScheduler {
  private var wakeTask: Task<Void, Never>?

  /// Cancels any pending wake.
  func cancel() {
    wakeTask?.cancel()
    wakeTask = nil
  }

  /// Suspends until `deadline`, then returns. Cancels any prior wait.
  ///
  /// Returns immediately when `deadline` is in the past. Cooperative cancellation
  /// ends the wait without throwing.
  func waitUntil(_ deadline: Date) async {
    cancel()
    let delay = deadline.timeIntervalSinceNow
    let nanoseconds: UInt64
    if delay <= 0 {
      nanoseconds = 0
    } else {
      let clamped = min(delay, Double(UInt64.max) / 1_000_000_000)
      nanoseconds = UInt64(clamped * 1_000_000_000)
    }

    let task = Task {
      do {
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        // Cancelled — caller observes Task.isCancelled after await.
      }
    }
    wakeTask = task
    await task.value
    wakeTask = nil
  }
}
