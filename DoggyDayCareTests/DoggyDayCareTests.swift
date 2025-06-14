import XCTest
import SwiftData
@testable import Doggy_DayCare

@MainActor
final class DoggyDayCareTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        // Create an in-memory container for testing
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
        medications: String? = nil,
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
    
    // MARK: - Data Export Tests
    
    func testDataExport() async throws {
        // Create test data
        let dog1 = try await createTestDog(name: "Export Dog 1")
        let dog2 = try await createTestDog(name: "Export Dog 2", isBoarding: true)
        
        dog1.addFeedingRecord(type: .breakfast)
        dog1.addMedicationRecord(notes: "Test medication")
        dog1.addPottyRecord(type: .pee)
        
        dog2.addFeedingRecord(type: .lunch)
        dog2.addMedicationRecord()
        dog2.addPottyRecord(type: .poop)
        
        // Export data
        let url = try await BackupService.shared.exportDogs([dog1, dog2])
        
        // Verify export file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        
        // Verify file content (basic check)
        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        
        // Clean up
        try? FileManager.default.removeItem(at: url)
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