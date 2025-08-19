import Foundation

// This struct combines a PersistentDog with its current Visit for UI display
// This replaces the legacy Dog model throughout the app
struct DogWithVisit: Identifiable, Codable {
    let persistentDog: PersistentDog
    var currentVisit: Visit?
    
    var id: UUID { persistentDog.id }
    
    // MARK: - Basic Properties (from PersistentDog)
    
    var name: String { persistentDog.name }
    var ownerName: String? { persistentDog.ownerName }
    var ownerPhoneNumber: String? { persistentDog.ownerPhoneNumber }
    var age: Int? { persistentDog.age }
    var gender: DogGender? { persistentDog.gender }
    var vaccinations: [VaccinationItem] { persistentDog.vaccinations }
    var isNeuteredOrSpayed: Bool? { persistentDog.isNeuteredOrSpayed }
    var allergiesAndFeedingInstructions: String? { persistentDog.allergiesAndFeedingInstructions }
    var profilePictureData: Data? { persistentDog.profilePictureData }
    var visitCount: Int { persistentDog.visitCount }
    var lastVisitDate: Date? { persistentDog.lastVisitDate }
    var isDeleted: Bool { persistentDog.isDeleted }
    var createdAt: Date { persistentDog.createdAt }
    var updatedAt: Date { persistentDog.updatedAt }
    var createdBy: String? { persistentDog.createdBy }
    var lastModifiedBy: String? { persistentDog.lastModifiedBy }
    
    // MARK: - Visit-Specific Properties (from current Visit)
    
    var arrivalDate: Date { currentVisit?.arrivalDate ?? Date() }
    var departureDate: Date? { currentVisit?.departureDate }
    var isBoarding: Bool { currentVisit?.isBoarding ?? false }
    var boardingEndDate: Date? { currentVisit?.boardingEndDate }
    var isDaycareFed: Bool { persistentDog.isDaycareFed }
    var notes: String? { persistentDog.notes }
    var specialInstructions: String? { persistentDog.specialInstructions }
    var needsWalking: Bool { persistentDog.needsWalking }
    var walkingNotes: String? { persistentDog.walkingNotes }
    
    // Activity records from current visit
    var feedingRecords: [FeedingRecord] { currentVisit?.feedingRecords ?? [] }
    var medicationRecords: [MedicationRecord] { currentVisit?.medicationRecords ?? [] }
    var pottyRecords: [PottyRecord] { currentVisit?.pottyRecords ?? [] }
    
    // Medication data from current visit (visit-specific)
    var medications: [Medication] { currentVisit?.medications ?? [] }
    var scheduledMedications: [ScheduledMedication] { currentVisit?.scheduledMedications ?? [] }
    
    // MARK: - Computed Properties
    
    var isCurrentlyPresent: Bool {
        return currentVisit?.isCurrentlyPresent ?? false
    }
    
    var shouldBeTreatedAsDaycare: Bool {
        return currentVisit?.shouldBeTreatedAsDaycare ?? true
    }
    
    var isArrivalTimeSet: Bool {
        return currentVisit?.isArrivalTimeSet ?? false
    }
    
    // MARK: - Activity Counts
    
    var breakfastCount: Int { currentVisit?.breakfastCount ?? 0 }
    var lunchCount: Int { currentVisit?.lunchCount ?? 0 }
    var dinnerCount: Int { currentVisit?.dinnerCount ?? 0 }
    var snackCount: Int { currentVisit?.snackCount ?? 0 }
    var medicationCount: Int { currentVisit?.medicationCount ?? 0 }
    var peeCount: Int { currentVisit?.peeCount ?? 0 }
    var poopCount: Int { currentVisit?.poopCount ?? 0 }
    
    // MARK: - Duration Properties
    
    var stayDuration: TimeInterval {
        guard let visit = currentVisit else { return 0 }
        let endDate = visit.departureDate ?? Date()
        guard endDate > visit.arrivalDate else { return 0 }
        return endDate.timeIntervalSince(visit.arrivalDate)
    }
    
    var formattedStayDuration: String {
        return currentVisit?.formattedStayDuration ?? ""
    }
    
    var formattedCurrentStayDuration: String {
        return currentVisit?.formattedCurrentStayDuration ?? ""
    }
    
    // MARK: - Medication Properties (from current Visit)
    
    var activeMedications: [Medication] { currentVisit?.activeMedications ?? [] }
    var dailyMedications: [Medication] { currentVisit?.dailyMedications ?? [] }
    var scheduledMedicationTypes: [Medication] { currentVisit?.scheduledMedicationTypes ?? [] }
    var pendingScheduledMedications: [ScheduledMedication] { currentVisit?.pendingScheduledMedications ?? [] }
    var overdueScheduledMedications: [ScheduledMedication] { currentVisit?.overdueScheduledMedications ?? [] }
    var todaysScheduledMedications: [ScheduledMedication] { currentVisit?.todaysScheduledMedications ?? [] }
    var hasMedications: Bool { currentVisit?.hasMedications ?? false }
    var hasScheduledMedications: Bool { currentVisit?.hasScheduledMedications ?? false }
    var needsMedicationAttention: Bool { currentVisit?.needsMedicationAttention ?? false }
    
    // MARK: - Initializers
    
    init(persistentDog: PersistentDog, currentVisit: Visit? = nil) {
        self.persistentDog = persistentDog
        self.currentVisit = currentVisit
    }
    
    // MARK: - Static Methods for Collections
    
    static func fromPersistentDogsAndVisits(_ persistentDogs: [PersistentDog], _ visits: [Visit]) -> [DogWithVisit] {
        return persistentDogs.map { persistentDog in
            let currentVisit = visits.first { $0.dogId == persistentDog.id && $0.isCurrentlyPresent }
            return DogWithVisit(persistentDog: persistentDog, currentVisit: currentVisit)
        }
    }
    
    // Include dogs that are currently present OR departed today (visible on main page)
    static func currentlyPresentFromPersistentDogsAndVisits(_ persistentDogs: [PersistentDog], _ visits: [Visit]) -> [DogWithVisit] {
        return persistentDogs.compactMap { persistentDog in
            // First check for currently present visits (original working logic)
            if let currentVisit = visits.first(where: { $0.dogId == persistentDog.id && $0.isCurrentlyPresent }) {
                return DogWithVisit(persistentDog: persistentDog, currentVisit: currentVisit)
            }
            
            // Then check for departed today visits (to show in departed today pane)
            if let departedVisit = visits.first(where: { 
                $0.dogId == persistentDog.id && 
                $0.departureDate != nil && 
                Calendar.current.isDateInToday($0.departureDate!)
            }) {
                return DogWithVisit(persistentDog: persistentDog, currentVisit: departedVisit)
            }
            
            return nil
        }
    }
    
    // Include dogs with future visits (for future bookings view)
    static func withFutureVisitsFromPersistentDogsAndVisits(_ persistentDogs: [PersistentDog], _ visits: [Visit]) -> [DogWithVisit] {
        let futureVisits = visits.filter { visit in
            let today = Calendar.current.startOfDay(for: Date())
            let visitDate = Calendar.current.startOfDay(for: visit.arrivalDate)
            return visitDate > today
        }
        
        return persistentDogs.compactMap { persistentDog in
            if let futureVisit = futureVisits.first(where: { $0.dogId == persistentDog.id }) {
                return DogWithVisit(persistentDog: persistentDog, currentVisit: futureVisit)
            }
            return nil
        }
    }
}

// MARK: - Custom Equality Implementation

extension DogWithVisit: Equatable {
    /// Custom equality that compares meaningful fields only (ignores timestamps and metadata)
    /// This prevents false conflicts from timestamp precision differences
    static func == (lhs: DogWithVisit, rhs: DogWithVisit) -> Bool {
        #if DEBUG
        let dogName = lhs.persistentDog.name
        #endif
        
        // Compare PersistentDog meaningful fields (exclude metadata like timestamps and counts)
        guard lhs.persistentDog.id == rhs.persistentDog.id,
              lhs.persistentDog.name == rhs.persistentDog.name,
              lhs.persistentDog.ownerName == rhs.persistentDog.ownerName,
              lhs.persistentDog.ownerPhoneNumber == rhs.persistentDog.ownerPhoneNumber,
              lhs.persistentDog.age == rhs.persistentDog.age,
              lhs.persistentDog.gender == rhs.persistentDog.gender,
              lhs.persistentDog.isNeuteredOrSpayed == rhs.persistentDog.isNeuteredOrSpayed,
              lhs.persistentDog.allergiesAndFeedingInstructions == rhs.persistentDog.allergiesAndFeedingInstructions,
              lhs.persistentDog.profilePictureData == rhs.persistentDog.profilePictureData,
              lhs.persistentDog.needsWalking == rhs.persistentDog.needsWalking,
              lhs.persistentDog.walkingNotes == rhs.persistentDog.walkingNotes,
              lhs.persistentDog.isDaycareFed == rhs.persistentDog.isDaycareFed,
              lhs.persistentDog.notes == rhs.persistentDog.notes,
              lhs.persistentDog.specialInstructions == rhs.persistentDog.specialInstructions,
              lhs.persistentDog.isDeleted == rhs.persistentDog.isDeleted,
              vaccinationsAreEqual(lhs.persistentDog.vaccinations, rhs.persistentDog.vaccinations) else {
            // EXCLUDED: visitCount, lastVisitDate, createdAt, updatedAt, createdBy, lastModifiedBy
            #if DEBUG
            print("🔍 DogWithVisit inequality detected for: \(dogName)")
            if lhs.persistentDog.name != rhs.persistentDog.name { print("  - Name differs") }
            if lhs.persistentDog.ownerName != rhs.persistentDog.ownerName { print("  - Owner name differs") }
            if lhs.persistentDog.ownerPhoneNumber != rhs.persistentDog.ownerPhoneNumber { print("  - Phone differs") }
            if !vaccinationsAreEqual(lhs.persistentDog.vaccinations, rhs.persistentDog.vaccinations) { 
                print("  - Vaccinations differ (likely date precision)")
                // More detailed vaccination debugging if needed
                for lhsVax in lhs.persistentDog.vaccinations {
                    if let rhsVax = rhs.persistentDog.vaccinations.first(where: { $0.name == lhsVax.name }) {
                        if let lhsDate = lhsVax.endDate, let rhsDate = rhsVax.endDate {
                            let diff = abs(lhsDate.timeIntervalSince(rhsDate))
                            if diff >= 1.0 {
                                print("    - \(lhsVax.name): dates differ by \(diff) seconds")
                            }
                        }
                    }
                }
            }
            // Add more specific field checks as needed
            #endif
            return false
        }
        
        // Compare Visit meaningful fields (both visits must exist or both nil)
        switch (lhs.currentVisit, rhs.currentVisit) {
        case (nil, nil):
            #if DEBUG
            print("✅ DogWithVisit considered equal for: \(dogName) (both have nil visits)")
            #endif
            return true
            
        case (let lhsVisit?, let rhsVisit?):
            return lhsVisit.isEqual(to: rhsVisit, ignoringTimestamps: true)
            
        case (nil, _), (_, nil):
            return false
        }
    }
}

// MARK: - Visit Equality Helper

extension Visit {
    /// Compare Visit objects ignoring timestamp precision and metadata
    func isEqual(to other: Visit, ignoringTimestamps: Bool = false) -> Bool {
        guard self.id == other.id,
              self.dogId == other.dogId,
              self.isBoarding == other.isBoarding,
              self.isArrivalTimeSet == other.isArrivalTimeSet,
              self.isDeleted == other.isDeleted,
              self.feedingRecords == other.feedingRecords,
              self.medicationRecords == other.medicationRecords,
              self.pottyRecords == other.pottyRecords,
              self.medications == other.medications,
              self.scheduledMedications == other.scheduledMedications else {
            return false
        }
        
        if ignoringTimestamps {
            // Compare dates with 1-second tolerance to handle precision differences
            return abs(self.arrivalDate.timeIntervalSince(other.arrivalDate)) < 1.0 &&
                   self.departureDate?.rounded() == other.departureDate?.rounded() &&
                   self.boardingEndDate?.rounded() == other.boardingEndDate?.rounded()
        } else {
            return self.arrivalDate == other.arrivalDate &&
                   self.departureDate == other.departureDate &&
                   self.boardingEndDate == other.boardingEndDate
        }
    }
}

// MARK: - Date Extension for Rounded Comparison

private extension Date {
    /// Rounds date to nearest second for comparison (eliminates microsecond differences)
    func rounded() -> Date {
        return Date(timeIntervalSince1970: self.timeIntervalSince1970.rounded())
    }
}

// MARK: - Vaccination Comparison Helper

private func vaccinationsAreEqual(_ lhs: [VaccinationItem], _ rhs: [VaccinationItem]) -> Bool {
    // Must have same count
    guard lhs.count == rhs.count else { return false }
    
    // Compare each vaccination by name and end date (with tolerance for date precision)
    for lhsVax in lhs {
        guard let rhsVax = rhs.first(where: { $0.name == lhsVax.name }) else {
            return false // Vaccination name not found in rhs
        }
        
        // Compare end dates with tolerance for CloudKit precision differences
        switch (lhsVax.endDate, rhsVax.endDate) {
        case (nil, nil):
            continue // Both nil, this vaccination matches
        case (let lhsDate?, let rhsDate?):
            // Both have dates - compare with 1 second tolerance
            if abs(lhsDate.timeIntervalSince(rhsDate)) >= 1.0 {
                return false // Dates differ by more than 1 second
            }
        case (nil, _), (_, nil):
            return false // One has date, other doesn't
        }
    }
    
    return true // All vaccinations match
}