//
//  Doggy_DayCareApp.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import CloudKit
import BackgroundTasks

@main
struct Doggy_DayCareApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var networkService = NetworkConnectivityService.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var advancedCache = AdvancedCache.shared
    @State private var isInitialized = false
    @State private var initializationError: String?
    @State private var ownerExists = false
    @State private var hasCheckedOwnerExistence = false
    @State private var isCheckingOwnerExistence = false
    @State private var isInitializingCloudKit = false
    
    init() {
        // Register background tasks
        registerBackgroundTasks()
    }
    
    private func registerBackgroundTasks() {
        // Register background task for automated backups
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.doggydaycare.backup", using: nil) { task in
            self.handleBackupBackgroundTask(task as! BGAppRefreshTask)
        }
        
        // Register background task for midnight transitions
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.doggydaycare.midnight", using: nil) { task in
            self.handleMidnightBackgroundTask(task as! BGAppRefreshTask)
        }
        
        #if DEBUG
        print("✅ Background tasks registered in main app")
        #endif
    }
    
    private func handleBackupBackgroundTask(_ task: BGAppRefreshTask) {
        #if DEBUG
        print("🔄 Background backup task started")
        #endif
        
        // Set up task expiration
        task.expirationHandler = {
            #if DEBUG
            print("⏰ Backup background task expired")
            #endif
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await AutomationService.shared.performAutomatedBackup()
            task.setTaskCompleted(success: true)
            
            // Schedule next backup task
            DispatchQueue.main.async {
                AutomationService.shared.scheduleBackgroundTasks()
            }
        }
    }
    
    private func handleMidnightBackgroundTask(_ task: BGAppRefreshTask) {
        #if DEBUG
        print("🔄 Background midnight task started")
        #endif
        
        // Set up task expiration
        task.expirationHandler = {
            #if DEBUG
            print("⏰ Midnight background task expired")
            #endif
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await AutomationService.shared.handleMidnightTransition()
            task.setTaskCompleted(success: true)
            
            // Schedule next midnight task
            DispatchQueue.main.async {
                AutomationService.shared.scheduleBackgroundTasks()
            }
        }
    }
    
    private func checkOwnerExistence() async {
        #if DEBUG
        print("🔍 APP DEBUG: Starting owner existence check at app level...")
        #endif
        
        if hasCheckedOwnerExistence {
            #if DEBUG
            print("🔍 APP DEBUG: Owner existence already checked, skipping...")
            #endif
            return
        }
        
        await MainActor.run {
            isCheckingOwnerExistence = true
        }
        
        do {
            let cloudKitService = CloudKitService.shared
            let allUsers = try await cloudKitService.fetchAllUsers()
            let owners = allUsers.filter { $0.isOwner && $0.isActive }
            
            #if DEBUG
            print("🔍 APP DEBUG: Found \(owners.count) active owners")
            for owner in owners {
                print("🔍 APP DEBUG: Owner: \(owner.name), email: \(owner.email ?? "none"), isOriginalOwner: \(owner.isOriginalOwner)")
            }
            #endif
            
            await MainActor.run {
                ownerExists = !owners.isEmpty
                hasCheckedOwnerExistence = true
                isCheckingOwnerExistence = false
                #if DEBUG
                print("🔍 APP DEBUG: ownerExists set to: \(ownerExists)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔍 APP DEBUG: Error checking for owner: \(error)")
            #endif
            await MainActor.run {
                ownerExists = false
                hasCheckedOwnerExistence = true
                isCheckingOwnerExistence = false
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !networkService.isConnected {
                    // Show no internet screen
                    NoInternetView()
                } else if let error = initializationError {
                    // Show error screen
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                        
                        Text("App Initialization Failed")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            // Reset and retry
                            initializationError = nil
                            isInitialized = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if !isInitialized {
                    // Show CloudKit initialization loading screen
                    VStack(spacing: 30) {
                        Image("GreenHouse_With_Dog")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 420, height: 420)
                        
                        VStack(spacing: 15) {
                            Text("Green House Doggy DayCare")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Initializing CloudKit...")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .task {
                        isInitializingCloudKit = true
                        #if DEBUG
                        print("🚀 Starting CloudKit initialization...")
                        #endif
                        
                        do {
                            try await dataManager.authenticate()
                            #if DEBUG
                            print("✅ CloudKit initialization completed successfully")
                            #endif
                            
                            // Check owner existence immediately after CloudKit is ready
                            await checkOwnerExistence()
                            
                            // Initialize automation service for automatic backups
                            _ = AutomationService.shared
                            #if DEBUG
                            print("✅ Automation service initialized")
                            #endif
                            
                            isInitialized = true
                            isInitializingCloudKit = false
                        } catch {
                            #if DEBUG
                            print("❌ CloudKit initialization failed: \(error)")
                            #endif
                            initializationError = "CloudKit setup failed: \(error.localizedDescription)"
                            isInitializingCloudKit = false
                        }
                    }
                } else {
                    if authService.currentUser == nil {
                        LoginView(ownerExists: ownerExists, hasCheckedOwnerExistence: hasCheckedOwnerExistence)
                            .environmentObject(dataManager)
                            .environmentObject(authService)
                    } else {
                        ContentView()
                            .environmentObject(dataManager)
                            .environmentObject(authService)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                #if DEBUG
                print("📱 App entering background")
                #endif
                UserDefaults.standard.set(Date(), forKey: "app_background_time")
                AutomationService.shared.applicationDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                #if DEBUG
                print("📱 App entering foreground")
                #endif
                AutomationService.shared.applicationWillEnterForeground()
                
                // Reset owner existence check if app was in background for a while
                if hasCheckedOwnerExistence {
                    let backgroundTime = UserDefaults.standard.object(forKey: "app_background_time") as? Date ?? Date()
                    let timeInBackground = Date().timeIntervalSince(backgroundTime)
                    
                    // If app was in background for more than 5 minutes, recheck owner existence
                    if timeInBackground > 300 {
                        #if DEBUG
                        print("🔍 APP DEBUG: App was in background for \(timeInBackground) seconds, rechecking owner existence")
                        #endif
                        hasCheckedOwnerExistence = false
                        Task {
                            await checkOwnerExistence()
                        }
                    }
                }
            }
        }
    }
}
