import SwiftUI
import UserNotifications

@MainActor
class AutomationService: ObservableObject {
    static let shared = AutomationService()
    private var timer: Timer?
    private var backupTimer: Timer?
    private var midnightTimer: Timer?
    
    private init() {
        print("🚀 AutomationService initializing...")
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
        print("🕐 Setting up backup timers...")
        
        // Instead of creating multiple timers, use a single timer that checks the time
        backupTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            print("🕐 Current time: \(hour):\(minute)")
            
            // Check if current time matches any backup time (with a 1-minute window)
            let shouldBackup = (hour == 12 && minute == 0) ||  // 12 PM
                             (hour == 18 && minute == 0) ||    // 6 PM
                             (hour == 23 && minute == 59)      // 11:59 PM
            
            if shouldBackup {
                print("🔄 Backup time reached! Triggering automated backup...")
                Task {
                    await self?.performAutomatedBackup()
                }
            }
        }
        RunLoop.main.add(backupTimer!, forMode: .common)
        print("✅ Backup timers set up successfully")
    }
    
    private func setupMidnightTransition() {
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        
        if let nextMidnight = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            midnightTimer = Timer(fire: nextMidnight, interval: 86400, repeats: true) { [weak self] _ in
                Task {
                    await self?.handleMidnightTransition()
                }
            }
            RunLoop.main.add(midnightTimer!, forMode: .common)
        }
    }
    
    private func checkDaycareDepartures() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogs()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            let daycareDogs = allDogs.filter { $0.shouldBeTreatedAsDaycare && $0.isCurrentlyPresent }
            
            if !daycareDogs.isEmpty {
                let dogNames = daycareDogs.map { $0.name }.joined(separator: ", ")
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
        print("🔄 Starting automated backup process...")
        
        // Only perform automatic backups for owners, not staff members
        let authService = AuthenticationService.shared
        guard let currentUser = authService.currentUser else {
            print("❌ No current user found - skipping backup")
            return
        }
        
        print("👤 Current user: \(currentUser.name), isOwner: \(currentUser.isOwner)")
        
        guard currentUser.isOwner else {
            print("⏭️ Skipping automatic backup - user is not an owner")
            return
        }
        
        do {
            print("📥 Fetching dogs from CloudKit...")
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogs()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            print("📊 Found \(allDogs.count) dogs to backup")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = dateFormatter.string(from: Date())
            
            print("💾 Creating backup file...")
            let url = try await BackupService.shared.exportDogs(allDogs, filename: "backup_\(timestamp)")
            print("✅ Automated backup created successfully at: \(url.path) for owner: \(currentUser.name)")
        } catch {
            print("❌ Error performing automated backup: \(error.localizedDescription)")
        }
    }
    
    private func handleMidnightTransition() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogs()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            
            let today = Date()
            print("Starting midnight transition for \(today.formatted())")
            
            for dog in allDogs {
                var updatedDog = dog
                var needsUpdate = false
                
                // Check if this is a future booking that should transition to main page
                if !dog.isArrivalTimeSet && Calendar.current.isDate(dog.arrivalDate, inSameDayAs: today) {
                    print("Transitioning future booking '\(dog.name)' to main page (arrival date: \(dog.arrivalDate.formatted()))")
                    // Keep the arrival date but mark that arrival time needs to be set
                    // The dog will now appear in the main page with a red background
                    needsUpdate = true
                }
                
                if dog.isBoarding {
                    if let boardingEndDate = dog.boardingEndDate {
                        // Note: Boarding dogs are now handled through shouldBeTreatedAsDaycare property
                        // They remain boarding dogs but are displayed as daycare when their end date arrives
                        print("📅 Boarding dog '\(dog.name)' (end date: \(boardingEndDate.formatted()), today: \(today.formatted()))")
                    } else {
                        print("⚠️ Boarding dog '\(dog.name)' (no end date set)")
                    }
                } else if dog.shouldBeTreatedAsDaycare && dog.isCurrentlyPresent {
                    // Only clear departure time for daycare dogs that are currently present
                    if dog.departureDate != nil {
                        print("🔄 Clearing departure time for daycare dog '\(dog.name)'")
                        updatedDog.departureDate = nil
                        needsUpdate = true
                    }
                }
                
                if needsUpdate {
                    _ = try await cloudKitService.updateDog(updatedDog.toCloudKitDog())
                }
            }
            
            print("Midnight transition completed successfully")
        } catch {
            print("Error handling midnight transition: \(error.localizedDescription)")
        }
    }
} 