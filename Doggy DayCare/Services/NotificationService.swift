import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            #if DEBUG
            print("🔔 Notification permission granted: \(granted)")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("❌ Failed to request notification permission: \(error)")
            #endif
            return false
        }
    }
    
    func scheduleMedicationNotification(for dog: DogWithVisit, scheduledMedication: ScheduledMedication) async {
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
            #if DEBUG
            print("✅ Scheduled medication notification for \(dog.name) at \(scheduledMedication.notificationTime)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule medication notification: \(error)")
            #endif
        }
    }
    
    func cancelMedicationNotification(for dog: DogWithVisit, scheduledMedication: ScheduledMedication) {
        let identifier = "medication-\(dog.id.uuidString)-\(scheduledMedication.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #if DEBUG
        print("✅ Cancelled medication notification for \(dog.name)")
        #endif
    }
    
    func cancelAllMedicationNotifications(for dog: DogWithVisit) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let medicationIdentifiers = requests
                .filter { $0.identifier.hasPrefix("medication-\(dog.id.uuidString)-") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: medicationIdentifiers)
            #if DEBUG
            print("✅ Cancelled all medication notifications for \(dog.name)")
            #endif
        }
    }
} 