import SwiftUI
import SwiftData
import UserNotifications

@MainActor
class AutomationService: ObservableObject {
    static let shared = AutomationService()
    private var timer: Timer?
    private var backupTimer: Timer?
    
    private init() {
        setupNotifications()
        setupTimers()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupTimers() {
        // Check for daycare dogs without departure time at 10:30 PM
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 22
        components.minute = 30
        
        if let nextCheck = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            timer = Timer(fire: nextCheck, interval: 86400, repeats: true) { [weak self] _ in
                Task {
                    await self?.checkDaycareDepartures()
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
        
        // Setup backup timers (12 PM, 6 PM, 11:59 PM)
        setupBackupTimers()
        
        // Setup midnight transition timer
        setupMidnightTransition()
    }
    
    private func setupBackupTimers() {
        // Instead of creating multiple timers, use a single timer that checks the time
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            // Check if current time matches any backup time
            let shouldBackup = (hour == 12 && minute == 0) ||  // 12 PM
                             (hour == 18 && minute == 0) ||    // 6 PM
                             (hour == 23 && minute == 59)      // 11:59 PM
            
            if shouldBackup {
                    Task {
                        await self?.performAutomatedBackup()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func setupMidnightTransition() {
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        
        if let nextMidnight = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            let timer = Timer(fire: nextMidnight, interval: 86400, repeats: true) { [weak self] _ in
                Task {
                    await self?.handleMidnightTransition()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func checkDaycareDepartures() async {
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { dog in
                !dog.isBoarding && dog.isCurrentlyPresent
            }
        )
        
        do {
            let modelContext = try ModelContainer(for: Dog.self).mainContext
            let dogs = try modelContext.fetch(descriptor)
            
            if !dogs.isEmpty {
                let dogNames = dogs.map { $0.name }.joined(separator: ", ")
                let content = UNMutableNotificationContent()
                content.title = "Daycare Dogs Still Present"
                content.body = "The following dogs still need departure times set: \(dogNames)"
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                
                try await UNUserNotificationCenter.current().add(request)
            }
        } catch {
            print("Error checking daycare departures: \(error.localizedDescription)")
        }
    }
    
    private func performAutomatedBackup() async {
        do {
            let modelContext = try ModelContainer(for: Dog.self).mainContext
            let descriptor = FetchDescriptor<Dog>()
            let dogs = try modelContext.fetch(descriptor)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = dateFormatter.string(from: Date())
            
            let url = try await BackupService.shared.exportDogs(dogs, filename: "backup_\(timestamp)")
            print("Automated backup created at: \(url.path)")
        } catch {
            print("Error performing automated backup: \(error.localizedDescription)")
        }
    }
    
    private func handleMidnightTransition() async {
        do {
            guard let modelContext = AuthenticationService.shared.modelContext else {
                print("Error: Model context not available")
                return
            }
            
            let descriptor = FetchDescriptor<Dog>()
            let allDogs = try modelContext.fetch(descriptor)
            
            let today = Date()
            print("Starting midnight transition for \(today.formatted())")
            
            for dog in allDogs {
                if dog.isBoarding {
                    if let boardingEndDate = dog.boardingEndDate {
                        // Only convert to daycare if boarding end date is today
                        if Calendar.current.isDate(boardingEndDate, inSameDayAs: today) {
                            print("Converting boarding dog '\(dog.name)' to daycare (boarding end date: \(boardingEndDate.formatted()))")
                            dog.isBoarding = false
                            dog.boardingEndDate = nil
                        } else {
                            print("Keeping '\(dog.name)' as boarding (end date: \(boardingEndDate.formatted()))")
                        }
                    } else {
                        print("Keeping '\(dog.name)' as boarding (no end date set)")
                    }
                } else if !dog.isBoarding && dog.isCurrentlyPresent {
                    // Only clear departure time for daycare dogs that are currently present
                    if dog.departureDate != nil {
                        print("Clearing departure time for daycare dog '\(dog.name)'")
                        dog.departureDate = nil
                    }
                }
            }
            
            try modelContext.save()
            print("Midnight transition completed successfully")
        } catch {
            print("Error handling midnight transition: \(error.localizedDescription)")
        }
    }
} 