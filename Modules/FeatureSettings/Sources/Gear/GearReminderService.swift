import Foundation
import UserNotifications
import UmiDB

@MainActor
final class GearReminderService {
    static let shared = GearReminderService()

    private init() {}

    func scheduleReminders(for items: [GearItem]) async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted == true else { return }

        let identifiers = items.map { reminderID(for: $0.id) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for item in items {
            guard let nextServiceDate = item.nextServiceDate else { continue }

            let warningDate = Calendar.current.date(byAdding: .day, value: -14, to: nextServiceDate)
                ?? nextServiceDate
            if warningDate < Date() {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Gear Service Reminder"
            content.body = "\(item.name) service is due soon."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: warningDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminderID(for: item.id),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    private func reminderID(for gearId: String) -> String {
        "gear-service-\(gearId)"
    }
}
