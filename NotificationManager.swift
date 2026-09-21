import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        // Tell the system that this class handles the notification behavior
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func sendMatchEndNotification(winner: String, loser: String) {
        let content = UNMutableNotificationContent()
        content.title = "Match Complete! 🏆"
        content.body = "\(winner) defeated \(loser)!"
        
        // FIXED: Use the full explicit path to avoid "switch statement" confusion
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner and play the sound even if the app is open
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Retention Reminders (toggle-time scheduling; zero launch cost)
    
    static let matchReminderID = "tennis-weekly-match"
    static let statsNudgeID = "tennis-stats-nudge"
    
    /// Enables/disables the weekly retention reminders. Scheduled on toggle,
    /// never at launch, so this cannot slow down app start.
    func setMatchReminders(enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.matchReminderID, Self.statsNudgeID]
        )
        guard enabled else { return }
        requestPermission()
        scheduleWeeklyReminder(
            id: Self.matchReminderID, weekday: 7, hour: 9,
            title: "Time for your weekly match! 🎾",
            body: "Your court is waiting. Open Vantage to start scoring."
        )
        scheduleWeeklyReminder(
            id: Self.statsNudgeID, weekday: 4, hour: 18,
            title: "Check your stats from last game 📊",
            body: "See how your win rate is trending in Vantage."
        )
    }
    
    private func scheduleWeeklyReminder(id: String, weekday: Int, hour: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling reminder: \(error.localizedDescription)")
            }
        }
    }
}
