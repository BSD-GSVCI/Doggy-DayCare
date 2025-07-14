import SwiftUI
import UserNotifications
import BackgroundTasks

@MainActor
class AutomationService: ObservableObject {
    static let shared = AutomationService()
    private var timer: Timer?
    private var backupTimer: Timer?
    private var midnightTimer: Timer?
    
    private let historyService = HistoryService.shared
    
    private init() {
        print("🚀 AutomationService initializing...")
        setupNotifications()
        setupTimers()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Methods for Background Tasks
    
    func performAutomatedBackup() async {
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
            // Use a separate fetch method that doesn't affect the UI sync status
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            print("📊 Found \(allDogs.count) dogs to backup")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = dateFormatter.string(from: Date())
            
            print("💾 Creating backup file...")
            
            // Try to get the backup folder URL from UserDefaults
            var backupFolderURL: URL? = nil
            if let bookmarkData = UserDefaults.standard.data(forKey: "backup_folder_bookmark") {
                do {
                    var isStale = false
                    backupFolderURL = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if isStale {
                        print("⚠️ Backup folder bookmark is stale, removing...")
                        UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                        backupFolderURL = nil
                    } else {
                        print("✅ Using backup folder: \(backupFolderURL?.path ?? "unknown")")
                    }
                } catch {
                    print("❌ Failed to resolve backup folder bookmark: \(error)")
                    UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                }
            }
            
            let url = try await BackupService.shared.exportDogs(allDogs, filename: "backup_\(timestamp)", to: backupFolderURL)
            print("✅ Automated backup created successfully at: \(url.path) for owner: \(currentUser.name)")
            
            // Additional debugging for file accessibility
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let permissions = attributes[.posixPermissions] as? Int ?? 0
                print("📁 Backup file details:")
                print("   - Path: \(url.path)")
                print("   - Size: \(fileSize) bytes")
                print("   - Permissions: \(permissions)")
                print("   - Readable: \(fileManager.isReadableFile(atPath: url.path))")
                print("   - Writable: \(fileManager.isWritableFile(atPath: url.path))")
                
                // Try to read the first few bytes to verify content
                if let data = try? Data(contentsOf: url) {
                    let firstBytes = data.prefix(50)
                    print("   - First 50 bytes: \(String(data: firstBytes, encoding: .utf8) ?? "unreadable")")
                }
            } else {
                print("❌ Backup file does not exist at expected path")
            }
            
            // Send notification about successful backup
            let content = UNMutableNotificationContent()
            content.title = "Backup Completed"
            content.body = "Daily backup completed successfully with \(allDogs.count) dogs"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "backup_\(timestamp)",
                content: content,
                trigger: nil
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
        } catch {
            print("❌ Error performing automated backup: \(error.localizedDescription)")
            
            // Create timestamp for error notification
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = dateFormatter.string(from: Date())
            
            // Send notification about failed backup
            let content = UNMutableNotificationContent()
            content.title = "Backup Failed"
            content.body = "Daily backup failed: \(error.localizedDescription)"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "backup_failed_\(timestamp)",
                content: content,
                trigger: nil
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("❌ Failed to send backup failure notification: \(error.localizedDescription)")
            }
        }
    }
    
    func handleMidnightTransition() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            
            let today = Date()
            print("Starting midnight transition for \(today.formatted())")
            
            // Record daily snapshot for history before making any changes
            print("📅 Recording daily snapshot for history...")
            
            // Get only visible dogs (same logic as ContentView)
            let visibleDogs = allDogs.filter { dog in
                // Include dogs that are currently present (daycare and boarding)
                let isCurrentlyPresent = dog.isCurrentlyPresent
                let isDaycare = isCurrentlyPresent && dog.shouldBeTreatedAsDaycare
                let isBoarding = isCurrentlyPresent && !dog.shouldBeTreatedAsDaycare
                let isDepartedToday = dog.departureDate != nil && Calendar.current.isDateInToday(dog.departureDate!)
                
                return isDaycare || isBoarding || isDepartedToday
            }
            
            historyService.recordDailySnapshot(dogs: visibleDogs)
            print("✅ Daily snapshot recorded for \(visibleDogs.count) visible dogs")
            
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
    
    func scheduleBackgroundTasks() {
        // Schedule backup tasks at specific times
        let calendar = Calendar.current
        let now = Date()
        
        // Define backup times
        let backupTimes = [
            (12, 0),   // 12 PM
            (18, 0),   // 6 PM
            (23, 59)   // 11:59 PM
        ]
        
        for (hour, minute) in backupTimes {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.second = 0
            
            if let nextBackupTime = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                let backupRequest = BGAppRefreshTaskRequest(identifier: "com.doggydaycare.backup")
                backupRequest.earliestBeginDate = nextBackupTime
                
                do {
                    try BGTaskScheduler.shared.submit(backupRequest)
                    print("✅ Backup background task scheduled for \(nextBackupTime)")
                } catch {
                    print("❌ Failed to schedule backup background task: \(error)")
                }
            }
        }
        
        // Schedule midnight task
        let midnightRequest = BGAppRefreshTaskRequest(identifier: "com.doggydaycare.midnight")
        var midnightComponents = DateComponents()
        midnightComponents.hour = 0
        midnightComponents.minute = 0
        midnightComponents.second = 0
        
        if let nextMidnight = calendar.nextDate(after: now, matching: midnightComponents, matchingPolicy: .nextTime) {
            midnightRequest.earliestBeginDate = nextMidnight
            
            do {
                try BGTaskScheduler.shared.submit(midnightRequest)
                print("✅ Midnight background task scheduled for \(nextMidnight)")
            } catch {
                print("❌ Failed to schedule midnight background task: \(error)")
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
        
        // Setup backup timers (12 PM, 6 PM, 11:59 PM) - for foreground use
        setupBackupTimers()
        
        // Setup midnight transition timer - for foreground use
        setupMidnightTransition()
        
        // Vaccination expiry check at 9:00 AM daily
        var vaccinationComponents = DateComponents()
        vaccinationComponents.hour = 9
        vaccinationComponents.minute = 0
        if let nextVaccinationCheck = calendar.nextDate(after: Date(), matching: vaccinationComponents, matchingPolicy: .nextTime) {
            let vaccinationTimer = Timer(fire: nextVaccinationCheck, interval: 86400, repeats: true) { [weak self] _ in
                Task {
                    await self?.checkVaccinationExpiries()
                }
            }
            RunLoop.main.add(vaccinationTimer, forMode: .common)
        }
        
        // Schedule background tasks
        scheduleBackgroundTasks()
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
    
    // MARK: - Background App Refresh Support
    
    func applicationDidEnterBackground() {
        print("📱 App entered background - scheduling background tasks")
        scheduleBackgroundTasks()
    }
    
    func applicationWillEnterForeground() {
        print("📱 App entering foreground")
        // Background tasks will continue to work, but we can also use foreground timers
    }
    
    // MARK: - Existing Methods
    
    private func checkDaycareDepartures() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
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
    
    private func checkVaccinationExpiries() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDog() }
            let today = Calendar.current.startOfDay(for: Date())
            let expiredDogs = allDogs.filter {
                if let endDate = $0.vaccinationEndDate {
                    return Calendar.current.startOfDay(for: endDate) <= today
                }
                return false
            }
            for dog in expiredDogs {
                let content = UNMutableNotificationContent()
                content.title = "Vaccination Expired"
                content.body = "The vaccination for \(dog.name) has expired. Please update their vaccination record."
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "vaccination_\(dog.id)",
                    content: content,
                    trigger: nil
                )
                try await UNUserNotificationCenter.current().add(request)
            }
        } catch {
            print("Error checking vaccination expiries: \(error.localizedDescription)")
        }
    }
    
    // MARK: - History Management
    
    func recordDailySnapshot() {
        print("📅 Manually recording daily snapshot...")
        let dataManager = DataManager.shared
        
        // Get only visible dogs (same logic as ContentView)
        let visibleDogs = dataManager.dogs.filter { dog in
            // Include dogs that are currently present (daycare and boarding)
            let isCurrentlyPresent = dog.isCurrentlyPresent
            let isDaycare = isCurrentlyPresent && dog.shouldBeTreatedAsDaycare
            let isBoarding = isCurrentlyPresent && !dog.shouldBeTreatedAsDaycare
            let isDepartedToday = dog.departureDate != nil && Calendar.current.isDateInToday(dog.departureDate!)
            
            return isDaycare || isBoarding || isDepartedToday
        }
        
        historyService.recordDailySnapshot(dogs: visibleDogs)
        print("✅ Daily snapshot recorded for \(visibleDogs.count) visible dogs")
    }
    
    func cleanupOldHistoryRecords() {
        print("🧹 Cleaning up old history records...")
        historyService.cleanupOldRecords()
        print("✅ History cleanup completed")
    }
} 