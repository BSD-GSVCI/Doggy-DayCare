//
//  Doggy_DayCareApp.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import SwiftData

@main
struct Doggy_DayCareApp: App {
    let container: ModelContainer
    
    init() {
        do {
            // Create a schema with our Dog model
        let schema = Schema([
                Dog.self
        ])
            
            // Configure the model container
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            // Initialize the container
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("Successfully initialized ModelContainer")
        } catch {
            print("Failed to initialize ModelContainer: \(error)")
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
