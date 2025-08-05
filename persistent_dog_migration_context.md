# Persistent Dog Migration - Context & Design

## Problem Identified

### Current Scalability Issue
- **Current approach**: Creates new `Dog` record for every visit
- **Scale problem**: 50 dogs/day × 365 days = 18,250 records/year
- **After 10 years**: 182,500+ records
- **Database view**: Queries ALL records every time
- **CloudKit limits**: ~200-400 records per query
- **Result**: Will hit CloudKit quotas, timeouts, performance issues

### Current Data Model Problems
1. **New UUID per visit**: Each visit creates new `Dog` object
2. **Deduplication complexity**: Use name/owner/phone to identify "same dog"
3. **Inconsistent `isDeleted`**: Only affects specific visit, not dog globally
4. **Import creates new dogs**: When importing, creates new UUID even for existing dogs
5. **Database view mismatch**: Import list and database view show different dogs due to different filtering

## Root Cause Analysis

### Why Current Approach Was Chosen
- **Simplicity**: Each visit is self-contained
- **No migration needed**: Could build on existing structure
- **Natural fit**: Each day is a separate "visit"
- **Easy to understand**: One record = one visit

### Why It's Not Sustainable
- **CloudKit quotas**: Will exceed storage and bandwidth limits
- **Query performance**: Exponentially slower with more records
- **Network costs**: Massive data transfer on every refresh
- **User experience**: 10+ second load times
- **Memory issues**: App crashes processing 180K records

## Solution: Persistent Dog Records + Visit Records

### New Data Model Design

```swift
// 1. PERSISTENT DOG RECORD (one per unique dog)
struct PersistentDog {
    let id: UUID // Persistent dog ID
    var name: String
    var ownerName: String?
    var ownerPhoneNumber: String?
    var visitCount: Int
    var lastVisitDate: Date?
    var isDeleted: Bool
    var age: Int?
    var gender: DogGender?
    var vaccinations: [VaccinationItem]
    var isNeuteredOrSpayed: Bool?
    var allergiesAndFeedingInstructions: String?
    var needsWalking: Bool
    var walkingNotes: String?
    var medications: [Medication] // Persistent medications
    var scheduledMedications: [ScheduledMedication] // Persistent scheduled meds
    var profilePictureData: Data?
    var createdAt: Date
    var updatedAt: Date
}

// 2. VISIT RECORD (one per visit)
struct Visit {
    let id: UUID // Visit-specific ID
    let dogId: UUID // Reference to persistent dog
    var arrivalDate: Date
    var departureDate: Date?
    var isBoarding: Bool
    var boardingEndDate: Date?
    var isDaycareFed: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Visit-specific records
    var feedingRecords: [FeedingRecord]
    var medicationRecords: [MedicationRecord]
    var pottyRecords: [PottyRecord]
}
```

### CloudKit Schema

```swift
// CloudKit Record Types
enum RecordTypes {
    static let persistentDog = "PersistentDog"
    static let visit = "Visit"
    static let feedingRecord = "FeedingRecord"
    static let medicationRecord = "MedicationRecord"
    static let pottyRecord = "PottyRecord"
}

// Persistent Dog Fields
struct PersistentDogFields {
    static let id = "id"
    static let name = "name"
    static let ownerName = "ownerName"
    static let ownerPhoneNumber = "ownerPhoneNumber"
    static let visitCount = "visitCount"
    static let lastVisitDate = "lastVisitDate"
    static let isDeleted = "isDeleted"
    // ... other fields
}

// Visit Fields
struct VisitFields {
    static let id = "id"
    static let dogId = "dogId" // Reference to persistent dog
    static let arrivalDate = "arrivalDate"
    static let departureDate = "departureDate"
    static let isBoarding = "isBoarding"
    static let boardingEndDate = "boardingEndDate"
    static let isDaycareFed = "isDaycareFed"
    static let notes = "notes"
    // ... other fields
}
```

## Query Patterns

### 1. Database View Queries
```swift
// Get all unique dogs (fast, small dataset)
func fetchAllDogsForDatabase() async -> [PersistentDog] {
    let uniqueDogs = try await cloudKitService.fetchPersistentDogs()
    
    // For each dog, get visit count and last visit
    for dog in uniqueDogs {
        dog.visitCount = await getVisitCount(for: dog.id)
        dog.lastVisitDate = await getLastVisitDate(for: dog.id)
    }
    
    return uniqueDogs
}
```

### 2. History Page Queries
```swift
// Get all visits for a specific dog
func getVisitHistory(for dogId: UUID) async -> [Visit] {
    let predicate = NSPredicate(format: "dogId == %@", dogId.uuidString)
    return try await cloudKitService.fetchVisits(predicate: predicate)
}

// Get all visits for a specific date
func getVisitsForDate(_ date: Date) async -> [Visit] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let predicate = NSPredicate(format: "arrivalDate >= %@ AND arrivalDate < %@", 
                               startOfDay as NSDate, endOfDay as NSDate)
    return try await cloudKitService.fetchVisits(predicate: predicate)
}
```

### 3. Main Page Queries
```swift
// Get currently present dogs
func fetchCurrentlyPresentDogs() async -> [PersistentDog] {
    // Get all persistent dogs
    let allDogs = try await cloudKitService.fetchPersistentDogs()
    
    // For each dog, check if they have an active visit
    var presentDogs: [PersistentDog] = []
    for dog in allDogs {
        if let activeVisit = await getActiveVisit(for: dog.id) {
            // Add visit-specific data to dog for display
            var dogWithVisitData = dog
            dogWithVisitData.currentVisit = activeVisit
            presentDogs.append(dogWithVisitData)
        }
    }
    
    return presentDogs
}
```

## Migration Strategy

### Phase 1: Create New Schema
```swift
// Add new CloudKit record types
// Create migration functions
func migrateExistingDogsToPersistentDogs() async {
    // 1. Get all existing dog records
    let existingDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
    
    // 2. Group by name/owner/phone
    let groupedDogs = groupDogsByNameAndOwner(existingDogs)
    
    // 3. Create persistent dog for each group
    for (key, dogs) in groupedDogs {
        let persistentDog = createPersistentDog(from: dogs)
        try await cloudKitService.createPersistentDog(persistentDog)
        
        // 4. Convert each dog record to visit record
        for dog in dogs {
            let visit = createVisit(from: dog, dogId: persistentDog.id)
            try await cloudKitService.createVisit(visit)
        }
    }
}
```

## Benefits of New Approach

### ✅ Scalability
- **50 persistent dogs** instead of 18,250 records
- **Fast queries** for database view
- **Paginated visit history** for history page

### ✅ Complete Data Preservation
- All visit-specific data preserved
- History page works exactly as before
- All records (feeding, medication, potty) maintained

### ✅ Performance
- Database view: Query 50 dogs instead of 18,250
- History page: Query visits for specific date/dog
- Main page: Query active visits only

### ✅ Business Logic
- Natural fit for daycare (customers with visit history)
- Easy to implement "regular customer" features
- Better analytics and reporting

## Implementation Plan

1. **Design new schema** (PersistentDog + Visit)
2. **Create migration functions** to convert existing data
3. **Update CloudKit schema** with new record types
4. **Migrate existing data** (can be done incrementally)
5. **Update app logic** to use new model
6. **Test thoroughly** with existing data
7. **Deploy gradually** to ensure stability

## Current Issues to Address

### 1. Database View vs Import List Mismatch
- **Problem**: Different filtering logic causes different results
- **Solution**: Standardize filtering across both views

### 2. `isDeleted` Flag Complexity
- **Problem**: Inconsistent application across different views
- **Solution**: Use persistent dog model where `isDeleted` affects entire dog

### 3. CloudKit Query Limits
- **Problem**: Current approach will hit CloudKit limits
- **Solution**: New model reduces query size dramatically

## Next Steps

1. **Implement persistent dog schema**
2. **Create migration functions**
3. **Update CloudKit schema**
4. **Test migration with sample data**
5. **Deploy incrementally**
6. **Monitor performance improvements**

---

**Note**: This migration addresses the fundamental scalability issue while preserving all existing functionality and data. 