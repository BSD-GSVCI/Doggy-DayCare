import XCTest
import SwiftData
@testable import Doggy_DayCare

final class DoggyDayCareTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create an in-memory container for testing
        let schema = Schema([Dog.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        modelContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func createTestDog(
        name: String,
        isBoarding: Bool,
        arrivalDate: Date,
        departureDate: Date? = nil,
        boardingEndDate: Date? = nil
    ) -> Dog {
        let dog = Dog(
            name: name,
            isBoarding: isBoarding,
            arrivalDate: arrivalDate,
            departureDate: departureDate,
            boardingEndDate: boardingEndDate
        )
        modelContext.insert(dog)
        return dog
    }
    
    // MARK: - Correctness Tests
    
    func testDogCurrentlyPresent() throws {
        let now = Date()
        let calendar = Calendar.current
        
        // Test case 1: Dog has arrived but not departed
        let arrivalTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let dog1 = createTestDog(name: "Test1", isBoarding: false, arrivalDate: arrivalTime)
        XCTAssertTrue(dog1.isCurrentlyPresent)
        
        // Test case 2: Dog has departed
        let departureTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)!
        let dog2 = createTestDog(
            name: "Test2",
            isBoarding: false,
            arrivalDate: arrivalTime,
            departureDate: departureTime
        )
        XCTAssertFalse(dog2.isCurrentlyPresent)
        
        // Test case 3: Dog hasn't arrived yet (no arrival time set)
        let futureArrival = calendar.date(byAdding: .hour, value: 1, to: now)!
        let dog3 = createTestDog(name: "Test3", isBoarding: false, arrivalDate: futureArrival)
        XCTAssertFalse(dog3.isCurrentlyPresent)
    }
    
    func testDogArrivingToday() throws {
        let now = Date()
        let calendar = Calendar.current
        
        // Test case 1: Dog arriving today, hasn't arrived yet
        let todayArrival = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        let dog1 = createTestDog(name: "Test1", isBoarding: false, arrivalDate: todayArrival)
        XCTAssertTrue(dog1.isArrivingToday)
        
        // Test case 2: Dog arriving today, has already arrived
        let pastArrival = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let dog2 = createTestDog(name: "Test2", isBoarding: false, arrivalDate: pastArrival)
        XCTAssertFalse(dog2.isArrivingToday)
        
        // Test case 3: Dog arriving tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dog3 = createTestDog(name: "Test3", isBoarding: false, arrivalDate: tomorrow)
        XCTAssertFalse(dog3.isArrivingToday)
    }
    
    func testFutureBooking() throws {
        let now = Date()
        let calendar = Calendar.current
        
        // Test case 1: Future booking
        let futureDate = calendar.date(byAdding: .day, value: 1, to: now)!
        let dog1 = createTestDog(name: "Test1", isBoarding: false, arrivalDate: futureDate)
        XCTAssertTrue(dog1.isFutureBooking)
        
        // Test case 2: Today's booking
        let today = calendar.startOfDay(for: now)
        let dog2 = createTestDog(name: "Test2", isBoarding: false, arrivalDate: today)
        XCTAssertFalse(dog2.isFutureBooking)
        
        // Test case 3: Past booking
        let pastDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let dog3 = createTestDog(name: "Test3", isBoarding: false, arrivalDate: pastDate)
        XCTAssertFalse(dog3.isFutureBooking)
    }
    
    // MARK: - Performance Tests
    
    func testFilteringPerformance() throws {
        // Create a large dataset of dogs
        let calendar = Calendar.current
        let now = Date()
        var dogs: [Dog] = []
        
        // Create 1000 test dogs with various states
        for i in 0..<1000 {
            let isBoarding = i % 2 == 0
            let daysOffset = (i % 7) - 3 // -3 to +3 days
            let arrivalDate = calendar.date(byAdding: .day, value: daysOffset, to: now)!
            let hasDeparted = i % 3 == 0
            let departureDate = hasDeparted ? calendar.date(byAdding: .hour, value: 8, to: arrivalDate) : nil
            
            let dog = createTestDog(
                name: "TestDog\(i)",
                isBoarding: isBoarding,
                arrivalDate: arrivalDate,
                departureDate: departureDate
            )
            dogs.append(dog)
        }
        
        // Test performance of filtering operations
        measure {
            // Test daycare dogs filtering
            _ = dogs.filter { dog in
                !dog.isBoarding && !dog.isFutureBooking && (dog.isCurrentlyPresent || dog.isArrivingToday)
            }
            
            // Test boarding dogs filtering
            _ = dogs.filter { dog in
                dog.isBoarding && !dog.isFutureBooking && (dog.isCurrentlyPresent || dog.isArrivingToday)
            }
            
            // Test departed dogs filtering
            _ = dogs.filter { !$0.isCurrentlyPresent }
                .sorted { ($0.departureDate ?? Date()) > ($1.departureDate ?? Date()) }
        }
    }
    
    func testDateCalculationPerformance() throws {
        let now = Date()
        let calendar = Calendar.current
        
        // Create a test dog
        let dog = createTestDog(
            name: "PerformanceTest",
            isBoarding: false,
            arrivalDate: now
        )
        
        // Test performance of date calculations
        measure {
            for _ in 0..<1000 {
                _ = dog.isCurrentlyPresent
                _ = dog.isArrivingToday
                _ = dog.isFutureBooking
            }
        }
    }
}

// MARK: - Dog Extensions for Testing

private extension Dog {
    var isCurrentlyPresent: Bool {
        let calendar = Calendar.current
        let hasArrived = calendar.dateComponents([.hour, .minute], from: arrivalDate).hour != 0 ||
                        calendar.dateComponents([.hour, .minute], from: arrivalDate).minute != 0
        return hasArrived && departureDate == nil
    }
    
    var isArrivingToday: Bool {
        let calendar = Calendar.current
        let isArrivingToday = calendar.isDateInToday(arrivalDate)
        let hasArrived = calendar.dateComponents([.hour, .minute], from: arrivalDate).hour != 0 ||
                        calendar.dateComponents([.hour, .minute], from: arrivalDate).minute != 0
        return isArrivingToday && !hasArrived
    }
    
    var isFutureBooking: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: arrivalDate) > calendar.startOfDay(for: Date())
    }
} 