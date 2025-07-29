import XCTest
import SwiftData
@testable import Doggy_DayCare

@MainActor
final class DoggyDayCareTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Dog.self, configurations: config)
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Helper Methods
    
    private func createTestDog(
        name: String = "Test Dog",
        arrivalDate: Date = Date(),
        departureDate: Date? = nil,
        boardingEndDate: Date? = nil,
        isBoarding: Bool = false,
        isDaycareFed: Bool = false,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,

        notes: String? = nil
    ) async throws -> Dog {
        let dog = Dog(
            name: name,
            arrivalDate: arrivalDate,
            departureDate: departureDate,
            boardingEndDate: boardingEndDate,
            isBoarding: isBoarding,
            isDaycareFed: isDaycareFed,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            specialInstructions: nil,
            medications: medications,
            notes: notes,
            modelContext: modelContext
        )
        modelContext.insert(dog)
        try modelContext.save()
        return dog
    }
    
    // MARK: - Dog Model Tests
    
    func testDogCreation() async throws {
        let dog = try await createTestDog()
        XCTAssertNotNil(dog.id)
        XCTAssertEqual(dog.name, "Test Dog")
        XCTAssertFalse(dog.isBoarding)
        XCTAssertFalse(dog.isDaycareFed)
        XCTAssertFalse(dog.needsWalking)
        XCTAssertNil(dog.departureDate)
        XCTAssertNil(dog.boardingEndDate)
        XCTAssertNil(dog.walkingNotes)
        XCTAssertNil(dog.medications)
        XCTAssertNil(dog.notes)
        XCTAssertTrue(dog.feedingRecords.isEmpty)
        XCTAssertTrue(dog.medicationRecords.isEmpty)
        XCTAssertTrue(dog.pottyRecords.isEmpty)
    }
    
    func testDogModification() async throws {
        let dog = try await createTestDog()
        
        // Modify dog properties
        dog.name = "Updated Dog"
        dog.isBoarding = true
        dog.isDaycareFed = true
        dog.needsWalking = true
        dog.walkingNotes = "Test walking notes"
        dog.medications = "Test medications"
        dog.notes = "Test notes"
        
        try modelContext.save()
        
        // Verify changes persisted
        XCTAssertEqual(dog.name, "Updated Dog")
        XCTAssertTrue(dog.isBoarding)
        XCTAssertTrue(dog.isDaycareFed)
        XCTAssertTrue(dog.needsWalking)
        XCTAssertEqual(dog.walkingNotes, "Test walking notes")
        XCTAssertEqual(dog.medications, "Test medications")
        XCTAssertEqual(dog.notes, "Test notes")
    }
    
    // MARK: - Feeding Records Tests
    
    func testFeedingRecords() async throws {
        let dog = try await createTestDog()
        
        // Add feeding records
        dog.addFeedingRecord(type: .breakfast)
        dog.addFeedingRecord(type: .lunch)
        dog.addFeedingRecord(type: .dinner)
        dog.addFeedingRecord(type: .snack)
        
        try modelContext.save()
        
        // Verify counts
        XCTAssertEqual(dog.breakfastCount, 1)
        XCTAssertEqual(dog.lunchCount, 1)
        XCTAssertEqual(dog.dinnerCount, 1)
        XCTAssertEqual(dog.snackCount, 1)
        
        // Verify record types
        let breakfastRecords = dog.feedingRecords.filter { $0.type == .breakfast }
        let lunchRecords = dog.feedingRecords.filter { $0.type == .lunch }
        let dinnerRecords = dog.feedingRecords.filter { $0.type == .dinner }
        let snackRecords = dog.feedingRecords.filter { $0.type == .snack }
        
        XCTAssertEqual(breakfastRecords.count, 1)
        XCTAssertEqual(lunchRecords.count, 1)
        XCTAssertEqual(dinnerRecords.count, 1)
        XCTAssertEqual(snackRecords.count, 1)
        
        // Verify timestamps
        for record in dog.feedingRecords {
            XCTAssertTrue(Calendar.current.isDateInToday(record.timestamp))
        }
    }
    
    // MARK: - Medication Records Tests
    
    func testMedicationRecords() async throws {
        let dog = try await createTestDog(medications: "Test medication")
        
        // Add medication records
        dog.addMedicationRecord()
        dog.addMedicationRecord(notes: "Test notes")
        
        try modelContext.save()
        
        // Verify counts and content
        XCTAssertEqual(dog.medicationCount, 2)
        XCTAssertEqual(dog.medicationRecords.count, 2)
        XCTAssertNil(dog.medicationRecords[0].notes)
        XCTAssertEqual(dog.medicationRecords[1].notes, "Test notes")
        
        // Verify timestamps
        for record in dog.medicationRecords {
            XCTAssertTrue(Calendar.current.isDateInToday(record.timestamp))
        }
    }
    
    // MARK: - Potty Records Tests
    
    func testPottyRecords() async throws {
        let dog = try await createTestDog(needsWalking: true)
        
        // Add potty records
        dog.addPottyRecord(type: .pee)
        dog.addPottyRecord(type: .poop)
        
        try modelContext.save()
        
        // Verify counts
        XCTAssertEqual(dog.peeCount, 1)
        XCTAssertEqual(dog.poopCount, 1)
        
        // Verify record types
        let peeRecords = dog.pottyRecords.filter { $0.type == .pee }
        let poopRecords = dog.pottyRecords.filter { $0.type == .poop }
        
        XCTAssertEqual(peeRecords.count, 1)
        XCTAssertEqual(poopRecords.count, 1)
        
        // Verify timestamps
        for record in dog.pottyRecords {
            XCTAssertTrue(Calendar.current.isDateInToday(record.timestamp))
        }
    }
    
    // MARK: - Stay Duration Tests
    
    func testStayDuration() async throws {
        let now = Date()
        let dog = try await createTestDog(arrivalDate: now)
        
        // Test current stay duration
        XCTAssertTrue(dog.isCurrentlyPresent)
        XCTAssertEqual(dog.stayDuration, 0, accuracy: 1.0) // Allow 1 second margin
        
        // Test departed stay duration
        let departureDate = now.addingTimeInterval(3600) // 1 hour later
        dog.departureDate = departureDate
        try modelContext.save()
        
        XCTAssertEqual(dog.stayDuration, 3600, accuracy: 1.0)
        
        // Test formatted duration
        XCTAssertEqual(dog.formattedStayDuration, "1h 0m")
        
        // Test longer duration (3 days)
        let longDepartureDate = now.addingTimeInterval(3 * 24 * 3600) // 3 days later
        dog.departureDate = longDepartureDate
        try modelContext.save()
        
        XCTAssertEqual(dog.formattedStayDuration, "3d 0h 0m")
        
        // Test duration with hours and minutes
        let mediumDepartureDate = now.addingTimeInterval(2 * 24 * 3600 + 5 * 3600 + 30 * 60) // 2 days, 5 hours, 30 minutes
        dog.departureDate = mediumDepartureDate
        try modelContext.save()
        
        XCTAssertEqual(dog.formattedStayDuration, "2d 5h 30m")
        
        // Test current stay duration for present dogs
        let currentDog = try await createTestDog(name: "Current Dog")
        XCTAssertTrue(currentDog.isCurrentlyPresent)
        XCTAssertFalse(currentDog.formattedCurrentStayDuration.isEmpty)
        
        // Test that current stay duration shows some time (should be very small for just created dog)
        let currentDuration = currentDog.formattedCurrentStayDuration
        XCTAssertTrue(currentDuration.contains("m") || currentDuration.contains("h") || currentDuration.contains("d"))
    }
    
    // MARK: - Future Bookings Tests
    
    func testFutureBookings() async throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let dog = try await createTestDog(
            name: "Future Dog",
            arrivalDate: tomorrow,
            boardingEndDate: Calendar.current.date(byAdding: .day, value: 3, to: tomorrow),
            isBoarding: true
        )
        
        // Verify future booking properties
        XCTAssertTrue(Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date()))
        XCTAssertNotNil(dog.boardingEndDate)
        XCTAssertTrue(dog.isBoarding)
    }
    
    // MARK: - Search and Filter Tests
    
    func testSearchAndFilter() async throws {
        // Create test dogs
        let dog1 = try await createTestDog(name: "Alpha Dog", isBoarding: false)
        let dog2 = try await createTestDog(name: "Beta Dog", isBoarding: true)
        let dog3 = try await createTestDog(name: "Charlie Dog", isBoarding: false)
        
        // Test daycare/boarding separation
        let daycareDogs = [dog1, dog2, dog3].filter { !$0.isBoarding }
        let boardingDogs = [dog1, dog2, dog3].filter { $0.isBoarding }
        
        XCTAssertEqual(daycareDogs.count, 2)
        XCTAssertEqual(boardingDogs.count, 1)
        
        // Test feeding record filtering
        dog1.addFeedingRecord(type: .breakfast)
        dog2.addFeedingRecord(type: .lunch)
        try modelContext.save()
        
        let dogsWithBreakfast = [dog1, dog2, dog3].filter { dog in
            dog.feedingRecords.contains { $0.type == .breakfast && Calendar.current.isDateInToday($0.timestamp) }
        }
        
        XCTAssertEqual(dogsWithBreakfast.count, 1)
        XCTAssertEqual(dogsWithBreakfast.first?.name, "Alpha Dog")
    }
    
    // MARK: - Dog Management Tests
    
    func testDepartureTimeSetting() async throws {
        let dog = try await createTestDog()
        let departureDate = Date().addingTimeInterval(86400) // 24 hours from now
        
        // Set departure time
        dog.departureDate = departureDate
        try modelContext.save()
        
        // Verify departure time was set
        XCTAssertEqual(dog.departureDate, departureDate)
        XCTAssertTrue(dog.isCurrentlyPresent) // Should be present since departure is in the future
        
        // Test removing departure time
        dog.departureDate = nil
        try modelContext.save()
        XCTAssertNil(dog.departureDate)
        XCTAssertTrue(dog.isCurrentlyPresent)
        
        // Test setting departure time in the past
        let pastDepartureDate = Date().addingTimeInterval(-3600) // 1 hour ago
        dog.departureDate = pastDepartureDate
        try modelContext.save()
        XCTAssertEqual(dog.departureDate, pastDepartureDate)
        XCTAssertFalse(dog.isCurrentlyPresent) // Should not be present since departure is in the past
    }
    
    func testSpecialInstructions() async throws {
        let dog = try await createTestDog()
        
        // Set special instructions
        dog.specialInstructions = "Test special instructions"
        try modelContext.save()
        
        // Verify special instructions
        XCTAssertEqual(dog.specialInstructions, "Test special instructions")
        
        // Test removing special instructions
        dog.specialInstructions = nil
        try modelContext.save()
        XCTAssertNil(dog.specialInstructions)
    }
    
    // MARK: - Record Management Tests
    
    func testFeedingRecordManagement() async throws {
        let dog = try await createTestDog()
        
        // Add feeding records
        dog.addFeedingRecord(type: .breakfast)
        dog.addFeedingRecord(type: .lunch)
        try modelContext.save()
        
        // Verify initial state
        XCTAssertEqual(dog.breakfastCount, 1)
        XCTAssertEqual(dog.lunchCount, 1)
        
        // Test record deletion
        if let breakfastRecord = dog.feedingRecords.first(where: { $0.type == .breakfast }) {
            dog.feedingRecords.removeAll { $0.timestamp == breakfastRecord.timestamp }
            try modelContext.save()
            XCTAssertEqual(dog.breakfastCount, 0)
        }
        
        // Test record editing (by removing and adding new)
        if let lunchRecord = dog.feedingRecords.first(where: { $0.type == .lunch }) {
            dog.feedingRecords.removeAll { $0.timestamp == lunchRecord.timestamp }
            dog.addFeedingRecord(type: .dinner) // Change type
            try modelContext.save()
            XCTAssertEqual(dog.lunchCount, 0)
            XCTAssertEqual(dog.dinnerCount, 1)
        }
    }
    
    func testMedicationRecordManagement() async throws {
        let dog = try await createTestDog()
        
        // Add medication records
        dog.addMedicationRecord()
        dog.addMedicationRecord(notes: "Test notes")
        try modelContext.save()
        
        // Verify initial state
        XCTAssertEqual(dog.medicationCount, 2)
        
        // Test record deletion
        if let firstRecord = dog.medicationRecords.first {
            dog.medicationRecords.removeAll { $0.timestamp == firstRecord.timestamp }
            try modelContext.save()
            XCTAssertEqual(dog.medicationCount, 1)
        }
        
        // Test record editing (by removing and adding new)
        if let secondRecord = dog.medicationRecords.first {
            dog.medicationRecords.removeAll { $0.timestamp == secondRecord.timestamp }
            dog.addMedicationRecord(notes: "Updated notes")
            try modelContext.save()
            XCTAssertEqual(dog.medicationCount, 1)
            XCTAssertEqual(dog.medicationRecords.first?.notes, "Updated notes")
        }
    }
    
    func testPottyRecordManagement() async throws {
        let dog = try await createTestDog()
        
        // Add potty records
        dog.addPottyRecord(type: .pee)
        dog.addPottyRecord(type: .poop)
        try modelContext.save()
        
        // Verify initial state
        XCTAssertEqual(dog.peeCount, 1)
        XCTAssertEqual(dog.poopCount, 1)
        
        // Test record deletion
        if let peeRecord = dog.pottyRecords.first(where: { $0.type == .pee }) {
            dog.removePottyRecord(at: peeRecord.timestamp)
            try modelContext.save()
            XCTAssertEqual(dog.peeCount, 0)
        }
        
        // Test record editing
        if let poopRecord = dog.pottyRecords.first(where: { $0.type == .poop }) {
            dog.updatePottyRecord(at: poopRecord.timestamp, type: .pee)
            try modelContext.save()
            XCTAssertEqual(dog.peeCount, 1)
            XCTAssertEqual(dog.poopCount, 0)
        }
    }
    
    // MARK: - Advanced Filtering Tests
    
    func testComplexFiltering() async throws {
        // Create test dogs with various states
        let dog1 = try await createTestDog(
            name: "Filter Dog 1",
            isBoarding: true,
            isDaycareFed: true,
            needsWalking: true
        )
        let dog2 = try await createTestDog(
            name: "Filter Dog 2",
            isBoarding: false,
            isDaycareFed: false,
            needsWalking: true
        )
        let dog3 = try await createTestDog(
            name: "Filter Dog 3",
            isBoarding: true,
            isDaycareFed: true,
            needsWalking: false
        )
        
        // Add some records
        dog1.addFeedingRecord(type: .breakfast)
        dog2.addMedicationRecord(notes: "Test medication")
        dog3.addPottyRecord(type: .pee)
        try modelContext.save()
        
        // Test complex filtering
        let boardingDogsWithFeeding = [dog1, dog2, dog3].filter { dog in
            dog.isBoarding && dog.breakfastCount > 0
        }
        XCTAssertEqual(boardingDogsWithFeeding.count, 1)
        XCTAssertEqual(boardingDogsWithFeeding.first?.name, "Filter Dog 1")
        
        let walkingDogsWithMedication = [dog1, dog2, dog3].filter { dog in
            dog.needsWalking && dog.medicationCount > 0
        }
        XCTAssertEqual(walkingDogsWithMedication.count, 1)
        XCTAssertEqual(walkingDogsWithMedication.first?.name, "Filter Dog 2")
    }
    
    // MARK: - Date Based Filtering Tests
    
    func testDateBasedFiltering() async throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Create dogs with different dates
        let dog1 = try await createTestDog(
            name: "Date Dog 1",
            arrivalDate: yesterday,
            departureDate: today
        )
        let dog2 = try await createTestDog(
            name: "Date Dog 2",
            arrivalDate: today
        )
        let dog3 = try await createTestDog(
            name: "Date Dog 3",
            arrivalDate: tomorrow
        )
        
        // Test current dogs
        let currentDogs = [dog1, dog2, dog3].filter { $0.isCurrentlyPresent }
        XCTAssertEqual(currentDogs.count, 1)
        XCTAssertEqual(currentDogs.first?.name, "Date Dog 2")
        
        // Test departed dogs
        let departedDogs = [dog1, dog2, dog3].filter { !$0.isCurrentlyPresent }
        XCTAssertEqual(departedDogs.count, 1)
        XCTAssertEqual(departedDogs.first?.name, "Date Dog 1")
        
        // Test future bookings
        let futureDogs = [dog1, dog2, dog3].filter { dog in
            Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: today)
        }
        XCTAssertEqual(futureDogs.count, 1)
        XCTAssertEqual(futureDogs.first?.name, "Date Dog 3")
    }
    
    // MARK: - Data Export Tests
    
    func testExportFormat() async throws {
        // Create test data
        let dog = try await createTestDog(
            name: "Export Test Dog",
            isBoarding: true,
            isDaycareFed: true,
            needsWalking: true,
            walkingNotes: "Test walking notes",
            medications: "Test medications",
            notes: "Test notes"
        )
        
        // Add various records
        dog.addFeedingRecord(type: .breakfast)
        dog.addMedicationRecord(notes: "Test medication")
        dog.addPottyRecord(type: .pee)
        try modelContext.save()
        
        // Export data
        let url = try await BackupService.shared.exportDogs([dog])
        
        // Verify file content
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8)!
        
        // Format dates for comparison
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let formattedArrivalDate = dateFormatter.string(from: dog.arrivalDate)
        
        // Check for essential data in export
        XCTAssertTrue(content.contains(dog.id.uuidString))
        XCTAssertTrue(content.contains(dog.name))
        XCTAssertTrue(content.contains(formattedArrivalDate))
        XCTAssertTrue(content.contains("true")) // isBoarding
        XCTAssertTrue(content.contains("Test walking notes"))
        XCTAssertTrue(content.contains("Test medications"))
        XCTAssertTrue(content.contains("Test notes"))
        
        // Clean up
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async throws {
        // Create 1000 test dogs
        measure {
            let dogs = (0..<1000).map { i in
                Dog(
                    name: "Performance Dog \(i)",
                    arrivalDate: Date(),
                    isBoarding: i % 2 == 0,
                    modelContext: modelContext
                )
            }
            // Insert dogs one at a time
            for dog in dogs {
                modelContext.insert(dog)
            }
            try? modelContext.save()
        }
        
        // Test search performance with large dataset using a more efficient predicate
        measure {
            let descriptor = FetchDescriptor<Dog>(
                predicate: #Predicate<Dog> { dog in
                    dog.name.contains("Performance")
                },
                sortBy: [SortDescriptor(\Dog.name)]
            )
            _ = try? modelContext.fetch(descriptor)
        }
        
        // Test filtering performance using a more efficient predicate
        measure {
            let descriptor = FetchDescriptor<Dog>(
                predicate: #Predicate<Dog> { dog in
                    dog.isBoarding && dog.isDaycareFed && dog.isCurrentlyPresent
                },
                sortBy: [SortDescriptor(\Dog.name)]
            )
            _ = try? modelContext.fetch(descriptor)
        }
        
        // Clean up
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { dog in
                dog.name.contains("Performance")
            }
        )
        let dogs = try modelContext.fetch(descriptor)
        dogs.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - View Tests

@MainActor
final class DoggyDayCareViewTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Dog.self, configurations: config)
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }
    
    func testContentView() async throws {
        let view = ContentView()
            .modelContainer(modelContainer)
        
        // Test view initialization
        XCTAssertNotNil(view)
        
        // Add test data and verify view updates
        let dog = Dog(
            name: "View Test Dog",
            arrivalDate: Date(),
            isBoarding: true,
            modelContext: modelContext
        )
        modelContext.insert(dog)
        try modelContext.save()
        
        // Note: More detailed view testing would require UI testing
    }
    
    func testFeedingListView() async throws {
        let view = FeedingListView()
            .modelContainer(modelContainer)
        
        // Test view initialization
        XCTAssertNotNil(view)
        
        // Add test data and verify filtering
        let dog1 = Dog(
            name: "Feeding Test Dog 1",
            arrivalDate: Date(),
            isBoarding: false,
            modelContext: modelContext
        )
        let dog2 = Dog(
            name: "Feeding Test Dog 2",
            arrivalDate: Date(),
            isBoarding: true,
            modelContext: modelContext
        )
        
        modelContext.insert(dog1)
        modelContext.insert(dog2)
        try modelContext.save()
        
        // Note: More detailed view testing would require UI testing
    }
}

// MARK: - Performance Tests

@MainActor
final class DoggyDayCarePerformanceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Dog.self, configurations: config)
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }
    
    func testFeedingRecordPerformance() async throws {
        let dog = Dog(
            name: "Performance Test Dog",
            arrivalDate: Date(),
            modelContext: modelContext
        )
        modelContext.insert(dog)
        try modelContext.save()
        
        measure {
            // Add 100 feeding records
            for _ in 0..<100 {
                dog.addFeedingRecord(type: .breakfast)
            }
            try? modelContext.save()
        }
    }
    
    func testSearchPerformance() async throws {
        // Create 100 test dogs
        for i in 0..<100 {
            let dog = Dog(
                name: "Search Test Dog \(i)",
                arrivalDate: Date(),
                modelContext: modelContext
            )
            modelContext.insert(dog)
        }
        try modelContext.save()
        
        measure {
            // Perform search
            let descriptor = FetchDescriptor<Dog>(
                predicate: #Predicate<Dog> { dog in
                    dog.name.localizedStandardContains("Test")
                }
            )
            _ = try? modelContext.fetch(descriptor)
        }
    }
} 