import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 Notification permission granted: \(granted)")
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func scheduleMedicationNotification(for dog: Dog, scheduledMedication: ScheduledMedication) async {
        let content = UNMutableNotificationContent()
        content.title = "Medication Due"
        content.body = "\(dog.name) needs medication: \(scheduledMedication.notes ?? "Scheduled medication")"
        content.sound = .default
        
        // Create trigger for the scheduled time
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledMedication.notificationTime),
            repeats: false
        )
        
        // Create unique identifier for this notification
        let identifier = "medication-\(dog.id.uuidString)-\(scheduledMedication.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled medication notification for \(dog.name) at \(scheduledMedication.notificationTime)")
        } catch {
            print("❌ Failed to schedule medication notification: \(error)")
        }
    }
    
    func cancelMedicationNotification(for dog: Dog, scheduledMedication: ScheduledMedication) {
        let identifier = "medication-\(dog.id.uuidString)-\(scheduledMedication.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("✅ Cancelled medication notification for \(dog.name)")
    }
    
    func cancelAllMedicationNotifications(for dog: Dog) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let medicationIdentifiers = requests
                .filter { $0.identifier.hasPrefix("medication-\(dog.id.uuidString)-") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: medicationIdentifiers)
            print("✅ Cancelled all medication notifications for \(dog.name)")
        }
    }
} 