import SwiftUI
import UserNotifications
import BackgroundTasks
import CloudKit

@MainActor
class AutomationService: ObservableObject {
    static let shared = AutomationService()
    private var timer: Timer?
    private var backupTimer: Timer?
    private var midnightTimer: Timer?
    
    private let cloudKitHistoryService = CloudKitHistoryService.shared
    
    private init() {
        #if DEBUG
        print("🚀 AutomationService initializing...")
        #endif
        setupNotifications()
        setupTimers()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            #if DEBUG
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Error requesting notification permission: \(error.localizedDescription)")
            }
            #endif
        }
    }
    
    // MARK: - Public Methods for Background Tasks
    
    func performAutomatedBackup() async {
        #if DEBUG
        print("🔄 Starting automated backup process...")
        #endif
        
        // Only perform automatic backups for owners and promoted owners, not staff members
        let authService = AuthenticationService.shared
        guard let currentUser = authService.currentUser else {
            #if DEBUG
            print("❌ No current user found - skipping backup")
            #endif
            return
        }
        
        #if DEBUG
        print("👤 Current user: \(currentUser.name), isOwner: \(currentUser.isOwner), isOriginalOwner: \(currentUser.isOriginalOwner)")
        #endif
        
        // Allow both original owners and promoted owners to perform backups
        guard currentUser.isOwner || currentUser.isOriginalOwner else {
            #if DEBUG
            print("⏭️ Skipping automatic backup - user is not an owner or promoted owner")
            #endif
            return
        }
        
        do {
            #if DEBUG
            print("📥 Fetching dogs from CloudKit...")
            #endif
            let cloudKitService = CloudKitService.shared
            // Use a separate fetch method that doesn't affect the UI sync status
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDogWithVisit() }
            #if DEBUG
            print("📊 Found \(allDogs.count) total dogs in CloudKit")
            #endif
            
            // Filter to only include visible dogs (same logic as ContentView)
            let visibleDogs = allDogs.filter { dog in
                // Include dogs that are currently present (daycare and boarding)
                let isCurrentlyPresent = dog.isCurrentlyPresent
                let isDaycare = isCurrentlyPresent && dog.shouldBeTreatedAsDaycare
                let isBoarding = isCurrentlyPresent && !dog.shouldBeTreatedAsDaycare
                let isDepartedToday = dog.departureDate != nil && Calendar.current.isDateInToday(dog.departureDate!)
                
                return isDaycare || isBoarding || isDepartedToday
            }
            
            #if DEBUG
            print("📊 Filtered to \(visibleDogs.count) visible dogs for backup")
            #endif
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = dateFormatter.string(from: Date())
            
            #if DEBUG
            print("💾 Creating backup file...")
            #endif
            
            // Try to get the backup folder URL from UserDefaults
            var backupFolderURL: URL? = nil
            if let bookmarkData = UserDefaults.standard.data(forKey: "backup_folder_bookmark") {
                do {
                    var isStale = false
                    backupFolderURL = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if isStale {
                        #if DEBUG
                        print("⚠️ Backup folder bookmark is stale, removing...")
                        #endif
                        UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                        backupFolderURL = nil
                    } else {
                        #if DEBUG
                        print("✅ Using backup folder: \(backupFolderURL?.path ?? "unknown")")
                        #endif
                    }
                } catch {
                    #if DEBUG
                    print("❌ Failed to resolve backup folder bookmark: \(error)")
                    #endif
                    UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                }
            }
            
            // Add .csv extension to the filename
            let url = try await BackupService.shared.exportDogs(visibleDogs, filename: "backup_\(timestamp).csv", to: backupFolderURL)
            #if DEBUG
            print("✅ Automated backup created successfully at: \(url.path) for user: \(currentUser.name)")
            #endif
            
            // Additional debugging for file accessibility
            #if DEBUG
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
                let permissions = attributes[FileAttributeKey.posixPermissions] as? Int ?? 0
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
            #endif
            
            // Send notification about successful backup
            let content = UNMutableNotificationContent()
            content.title = "Backup Completed"
            content.body = "Daily backup completed successfully with \(visibleDogs.count) visible dogs"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "backup_\(timestamp)",
                content: content,
                trigger: nil
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
        } catch {
            #if DEBUG
            print("❌ Error performing automated backup: \(error.localizedDescription)")
            
            // Log specific error details for debugging
            if let cloudKitError = error as? CKError {
                print("❌ CloudKit error code: \(cloudKitError.code.rawValue)")
                print("❌ CloudKit error description: \(cloudKitError.localizedDescription)")
                
                switch cloudKitError.code {
                case .permissionFailure:
                    print("❌ PERMISSION ERROR: User cannot access CloudKit records")
                    print("❌ This might be due to CloudKit container security settings")
                    print("❌ Check CloudKit Dashboard → Schema → Security Roles")
                case .notAuthenticated:
                    print("❌ AUTHENTICATION ERROR: User is not authenticated with CloudKit")
                case .networkFailure, .networkUnavailable:
                    print("❌ NETWORK ERROR: Cannot connect to CloudKit")
                case .quotaExceeded:
                    print("❌ QUOTA ERROR: CloudKit storage quota exceeded")
                default:
                    print("❌ Other CloudKit error: \(cloudKitError.code)")
                }
            }
            #endif
            
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
                #if DEBUG
                print("❌ Failed to send backup failure notification: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    func handleMidnightTransition() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDogWithVisit() }
            
            let today = Date()
            #if DEBUG
            print("Starting midnight transition for \(today.formatted())")
            #endif
            
            // Record daily snapshot for history before making any changes
            #if DEBUG
            print("📅 Recording daily snapshot for history...")
            #endif
            
            // Get only visible dogs (same logic as ContentView)
            let visibleDogs = allDogs.filter { dog in
                // Include dogs that are currently present (daycare and boarding)
                let isCurrentlyPresent = dog.isCurrentlyPresent
                let isDaycare = isCurrentlyPresent && dog.shouldBeTreatedAsDaycare
                let isBoarding = isCurrentlyPresent && !dog.shouldBeTreatedAsDaycare
                let isDepartedToday = dog.departureDate != nil && Calendar.current.isDateInToday(dog.departureDate!)
                
                return isDaycare || isBoarding || isDepartedToday
            }
            
            await cloudKitHistoryService.recordDailySnapshot(dogs: visibleDogs)
            #if DEBUG
            print("✅ Daily snapshot recorded for \(visibleDogs.count) visible dogs")
            #endif
            
            for dog in allDogs {
                var updatedDog = dog
                var needsUpdate = false
                
                // Check if this is a future booking that should transition to main page
                if !dog.isArrivalTimeSet && Calendar.current.isDate(dog.arrivalDate, inSameDayAs: today) {
                    #if DEBUG
                    print("Transitioning future booking '\(dog.name)' to main page (arrival date: \(dog.arrivalDate.formatted()))")
                    #endif
                    // Keep the arrival date but mark that arrival time needs to be set
                    // The dog will now appear in the main page with a red background
                    needsUpdate = true
                }
                
                if dog.isBoarding {
                    if let boardingEndDate = dog.boardingEndDate {
                        // Note: Boarding dogs are now handled through shouldBeTreatedAsDaycare property
                        // They remain boarding dogs but are displayed as daycare when their end date arrives
                        #if DEBUG
                        print("📅 Boarding dog '\(dog.name)' (end date: \(boardingEndDate.formatted()), today: \(today.formatted()))")
                        #endif
                    } else {
                        #if DEBUG
                        print("⚠️ Boarding dog '\(dog.name)' (no end date set)")
                        #endif
                    }
                } else if dog.shouldBeTreatedAsDaycare && dog.isCurrentlyPresent {
                    // Only clear departure time for daycare dogs that are currently present
                    if dog.departureDate != nil {
                        #if DEBUG
                        print("🔄 Clearing departure time for daycare dog '\(dog.name)'")
                        #endif
                        updatedDog.currentVisit?.departureDate = nil
                        updatedDog.currentVisit?.updatedAt = Date()
                        needsUpdate = true
                    }
                }
                
                if needsUpdate {
                    // Log automated updates
                    await DataManager.shared.logDogActivity(action: "AUTOMATED_UPDATE", dog: updatedDog, extra: "Automated midnight transition update")
                    // Update via DataManager instead of direct CloudKit call
                    if let visit = updatedDog.currentVisit {
                        try await VisitService.shared.updateVisit(visit)
                    }
                }
            }
            
            #if DEBUG
            print("Midnight transition completed successfully")
            #endif
        } catch {
            #if DEBUG
            print("Error handling midnight transition: \(error.localizedDescription)")
            #endif
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
                    #if DEBUG
                    print("✅ Backup background task scheduled for \(nextBackupTime)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to schedule backup background task: \(error)")
                    #endif
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
                #if DEBUG
                print("✅ Midnight background task scheduled for \(nextMidnight)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to schedule midnight background task: \(error)")
                #endif
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
        #if DEBUG
        print("🕐 Setting up backup timers...")
        #endif
        
        // Instead of creating multiple timers, use a single timer that checks the time
        backupTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            #if DEBUG
            print("🕐 Current time: \(hour):\(minute)")
            #endif
            
            // Check if current time matches any backup time (with a 1-minute window)
            let shouldBackup = (hour == 12 && minute == 0) ||  // 12 PM
                             (hour == 18 && minute == 0) ||    // 6 PM
                             (hour == 23 && minute == 59)      // 11:59 PM
            
            if shouldBackup {
                #if DEBUG
                print("🔄 Backup time reached! Triggering automated backup...")
                #endif
                Task {
                    await self?.performAutomatedBackup()
                }
            }
        }
        RunLoop.main.add(backupTimer!, forMode: .common)
        #if DEBUG
        print("✅ Backup timers set up successfully")
        #endif
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
        #if DEBUG
        print("📱 App entered background - scheduling background tasks")
        #endif
        scheduleBackgroundTasks()
    }
    
    func applicationWillEnterForeground() {
        #if DEBUG
        print("📱 App entering foreground")
        #endif
        // Background tasks will continue to work, but we can also use foreground timers
    }
    
    // MARK: - Existing Methods
    
    private func checkDaycareDepartures() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDogWithVisit() }
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
            #if DEBUG
            print("Error checking daycare departures: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func checkVaccinationExpiries() async {
        do {
            let cloudKitService = CloudKitService.shared
            let allCloudKitDogs = try await cloudKitService.fetchDogsForBackup()
            let allDogs = allCloudKitDogs.map { $0.toDogWithVisit() }
            let expiredDogs = allDogs.filter { dog in
                let today = Calendar.current.startOfDay(for: Date())
                return dog.vaccinations.contains { vax in
                    if let endDate = vax.endDate {
                        return Calendar.current.startOfDay(for: endDate) <= today
                    }
                    return false
                }
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
            #if DEBUG
            print("Error checking vaccination expiries: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - History Management
    
    func recordDailySnapshot() async {
        #if DEBUG
        print("📅 Manually recording daily snapshot...")
        #endif
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
        
        await cloudKitHistoryService.recordDailySnapshot(dogs: visibleDogs)
        #if DEBUG
        print("✅ Daily snapshot recorded for \(visibleDogs.count) visible dogs")
        #endif
    }
    
    func cleanupOldHistoryRecords() async {
        #if DEBUG
        print("🧹 Cleaning up old history records...")
        #endif
        await cloudKitHistoryService.cleanupOldRecords()
        #if DEBUG
        print("✅ History cleanup completed")
        #endif
    }
} 