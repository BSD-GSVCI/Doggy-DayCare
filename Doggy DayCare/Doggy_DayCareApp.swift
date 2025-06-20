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
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var isInitialized = false
    @State private var initializationError: String?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let error = initializationError {
                    // Show error screen instead of crashing
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
                            // Force app restart
                            exit(0)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if !isInitialized {
                    ProgressView("Initializing CloudKit...")
                        .task {
                            print("🚀 Starting CloudKit initialization...")
                            do {
                                try await cloudKitService.authenticate()
                                print("✅ CloudKit initialization completed successfully")
                                isInitialized = true
                            } catch {
                                print("❌ CloudKit initialization failed: \(error)")
                                initializationError = "CloudKit setup failed: \(error.localizedDescription)"
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(cloudKitService)
                }
            }
        }
    }
}
