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
    @State private var isInitialized = false
    @State private var initializationError: String?
    
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
        
        print("✅ Background tasks registered in main app")
    }
    
    private func handleBackupBackgroundTask(_ task: BGAppRefreshTask) {
        print("🔄 Background backup task started")
        
        // Set up task expiration
        task.expirationHandler = {
            print("⏰ Backup background task expired")
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
        print("🔄 Background midnight task started")
        
        // Set up task expiration
        task.expirationHandler = {
            print("⏰ Midnight background task expired")
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
                    // Show loading screen
                    VStack(spacing: 20) {
                        ProgressView("Initializing CloudKit...")
                            .scaleEffect(1.2)
                        
                        Text("Setting up data sync...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .task {
                        print("🚀 Starting CloudKit initialization...")
                        do {
                            try await dataManager.authenticate()
                            print("✅ CloudKit initialization completed successfully")
                            
                            // Password migration disabled - passwords already migrated and new users auto-save to CloudKit
                            // await authService.migrateExistingPasswords()
                            
                            // Initialize automation service for automatic backups
                            _ = AutomationService.shared
                            print("✅ Automation service initialized")
                            
                            isInitialized = true
                        } catch {
                            print("❌ CloudKit initialization failed: \(error)")
                            initializationError = "CloudKit setup failed: \(error.localizedDescription)"
                        }
                    }
                } else {
                    if authService.currentUser == nil {
                        LoginView()
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
                print("📱 App entering background")
                AutomationService.shared.applicationDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("📱 App entering foreground")
                AutomationService.shared.applicationWillEnterForeground()
            }
        }
    }
}
