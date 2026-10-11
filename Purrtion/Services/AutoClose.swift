import Foundation
import SwiftData
import BackgroundTasks
import UserNotifications

/// Nightly "Tag abschließen" for the previous day: scheduled for ~0:30 as a background task
/// (iOS decides the exact time, usually while charging) and caught up when the app is opened.
@MainActor
enum AutoClose {
    static let taskID = "com.const.purrtion.closeday"
    /// "vision." prefix → included in backups together with the other AI settings.
    static let enabledKey = "vision.autoCloseDay"
    private static let lastDayKey = "vision.autoCloseLastDay"
    private static let lastAttemptKey = "autoClose.lastAttempt"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    // MARK: Scheduling

    /// Must be called before the app finishes launching.
    nonisolated static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            Task { @MainActor in handle(task) }
        }
    }

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        guard isEnabled else { return }
        let cal = Calendar.current
        let now = Date()
        var start = cal.date(bySettingHour: 0, minute: 30, second: 0, of: now)!
        if start <= now { start = cal.date(byAdding: .day, value: 1, to: start)! }
        let request = BGProcessingTaskRequest(identifier: taskID)
        request.earliestBeginDate = start
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGTask) {
        schedule()   // next night
        let work = Task { @MainActor in
            let ok = await runIfNeeded(container: PurrtionApp.container)
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { work.cancel() }
    }

    // MARK: Running

    /// Analyses yesterday when enabled, after 0:30, not done yet and there is something to analyse.
    @discardableResult
    static func runIfNeeded(container: ModelContainer) async -> Bool {
        guard isEnabled else { return true }
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        guard now >= cal.date(bySettingHour: 0, minute: 30, second: 0, of: now)! else { return true }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetAutoClose") {
            defaults.removeObject(forKey: lastAttemptKey)
            defaults.removeObject(forKey: lastDayKey)
            let y = yesterday
            (try? container.mainContext.fetch(FetchDescriptor<DayReview>(predicate: #Predicate { $0.day == y })))?
                .forEach(container.mainContext.delete)
        }
        #endif
        if let last = defaults.object(forKey: lastDayKey) as? Date, last >= yesterday { return true }
        // After a failure or interruption (no network, missing key …) wait 20 minutes before trying again.
        if let attempt = defaults.object(forKey: lastAttemptKey) as? Date, now.timeIntervalSince(attempt) < 1200 { return false }

        let ctx = container.mainContext
        let d = yesterday
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d }))) ?? []
        let reviews = (try? ctx.fetch(FetchDescriptor<DayReview>(predicate: #Predicate { $0.day == d }))) ?? []
        guard !entries.isEmpty, reviews.isEmpty else {
            defaults.set(yesterday, forKey: lastDayKey)
            return true
        }

        defaults.set(now, forKey: lastAttemptKey)
        if UserDefaults.standard.bool(forKey: "activity.enabled") { await ActivityStore.refresh(days: 3) }
        do {
            let review = try await DayCloser.close(day: yesterday, goals: Goals(), ctx: ctx)
            review.automatic = true
            try? ctx.save()
            defaults.set(yesterday, forKey: lastDayKey)
            defaults.removeObject(forKey: lastAttemptKey)
            await notify(review)
            return true
        } catch {
            #if DEBUG
            print("AutoClose failed:", error)
            #endif
            return false
        }
    }

    // MARK: Notification

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func notify(_ review: DayReview) async {
        let content = UNMutableNotificationContent()
        content.title = "Dein Vortag ist analysiert 🐾"
        var body = "\(review.day.formatted(.dateTime.weekday(.wide))): \(review.rating)"
        if let score = review.score {
            body += " · Health Score \(score)"
            if let before = review.scoreBefore, before != score {
                body += " (\(score > before ? "+" : "−")\(abs(score - before)) durch KI)"
            }
        }
        content.body = body
        content.sound = .default
        content.userInfo = ["reviewDay": review.day.timeIntervalSince1970]
        let request = UNNotificationRequest(identifier: "review-\(Int(review.day.timeIntervalSince1970))",
                                            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("AutoClose notification failed:", error)
            #endif
        }
        #if DEBUG
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("AutoClose notified, authorization:", settings.authorizationStatus.rawValue, "alert:", settings.alertSetting.rawValue)
        #endif
    }
}

/// Shows notifications while the app is open and routes taps to the review.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationRouter()
    /// Set when a review notification was tapped – Today opens that day's verdict.
    @MainActor @Published var reviewDay: Date?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let t = response.notification.request.content.userInfo["reviewDay"] as? Double else { return }
        await MainActor.run { reviewDay = Date(timeIntervalSince1970: t) }
    }
}
