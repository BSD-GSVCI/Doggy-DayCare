//
//  Doggy_DayCareApp.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import CloudKit

@main
struct Doggy_DayCareApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var networkService = NetworkConnectivityService.shared
    @State private var isInitialized = false
    @State private var initializationError: String?
    
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
        }
    }
}
