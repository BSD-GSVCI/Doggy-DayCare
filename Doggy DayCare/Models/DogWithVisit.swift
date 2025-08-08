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
        return currentVisit != nil
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
    
    // Only include dogs that are currently present (have an active visit)
    static func currentlyPresentFromPersistentDogsAndVisits(_ persistentDogs: [PersistentDog], _ visits: [Visit]) -> [DogWithVisit] {
        return persistentDogs.compactMap { persistentDog in
            if let currentVisit = visits.first(where: { $0.dogId == persistentDog.id && $0.isCurrentlyPresent }) {
                return DogWithVisit(persistentDog: persistentDog, currentVisit: currentVisit)
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