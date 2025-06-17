//
//  Doggy_DayCareApp.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct Doggy_DayCareApp: App {
    let modelContainer: ModelContainer
    @State private var isInitialized = false
    
    init() {
        print("\n=== Initializing Doggy DayCare App ===")
        do {
            let schema = Schema([Dog.self, User.self, DogChange.self, FeedingRecord.self, MedicationRecord.self, PottyRecord.self])
            modelContainer = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            
            // Set up the model context for authentication service
            let context = modelContainer.mainContext
            print("Setting up model context in app initialization")
            AuthenticationService.shared.setModelContext(context)
            
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !isInitialized {
                    ProgressView("Initializing...")
                        .task {
                            await setupInitialData(modelContainer.mainContext)
                            isInitialized = true
                        }
                } else {
                    ContentView()
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
    private func setupInitialData(_ modelContext: ModelContext) async {
        print("\n=== Setting up initial data ===")
        
        // Check if we already have any users
        let descriptor = FetchDescriptor<User>()
        
        do {
            let existingUsers = try modelContext.fetch(descriptor)
            print("Found \(existingUsers.count) existing users")
            
            // Clean up test users
            for user in existingUsers {
                if user.email == "test@example.com" {
                    print("Removing test user: \(user.name)")
                    modelContext.delete(user)
                }
            }
            
            // Check specifically for existing owners
            let ownerDescriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.isOwner && user.isActive
                }
            )
            let existingOwners = try modelContext.fetch(ownerDescriptor)
            print("Found \(existingOwners.count) active owners")
            
            if existingOwners.isEmpty {
                print("No active owners found, creating initial owner account")
                // Create the first owner with isOriginalOwner set to true
                let owner = User(
                    id: UUID().uuidString,
                    name: "Owner",
                    email: "owner@doggydaycare.com",
                    isOwner: true,
                    isActive: true,
                    isWorkingToday: false,
                    isOriginalOwner: true  // Mark as original owner
                )
                modelContext.insert(owner)
                
                // Set the owner password
                let password = "Owner123"  // Default password
                UserDefaults.standard.set(password, forKey: "owner_password")
                print("Set initial owner password")
                
                try modelContext.save()
                print("Created initial owner account with email: \(owner.email ?? "none")")
            } else {
                print("Active owners found:")
                for owner in existingOwners {
                    print("- \(owner.name) (email: \(owner.email ?? "none"), isOriginalOwner: \(owner.isOriginalOwner))")
                }
            }
            
            // Print all users for debugging
            print("\nAll users in system:")
            let allUsers = try modelContext.fetch(descriptor)
            for user in allUsers {
                print("- \(user.name) (\(user.isOwner ? "Owner" : "Staff"))")
                if let email = user.email {
                    print("  Email: \(email)")
                }
                print("  Active: \(user.isActive)")
                if !user.isOwner {
                    print("  Working today: \(user.isWorkingToday)")
                }
                if user.isOriginalOwner {
                    print("  Original Owner: Yes")
                }
            }
            
            // Verify there's only one original owner
            let originalOwners = existingOwners.filter { $0.isOriginalOwner }
            if originalOwners.count > 1 {
                print("Warning: Found multiple original owners!")
                // Keep only the first original owner, mark others as regular owners
                for owner in originalOwners.dropFirst() {
                    owner.isOriginalOwner = false
                    print("Marked \(owner.name) as regular owner")
                }
                try? modelContext.save()
            }
            
            // Save any changes made during cleanup
            try modelContext.save()
            
        } catch {
            print("Error setting up initial data: \(String(describing: error))")
        }
        
        print("=== Initial data setup complete ===\n")
    }
}
