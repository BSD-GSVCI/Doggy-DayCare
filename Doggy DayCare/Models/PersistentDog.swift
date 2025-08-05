import Foundation

struct PersistentDog: Codable, Identifiable {
    let id: UUID
    var name: String
    var ownerName: String?
    var ownerPhoneNumber: String?
    var age: Int?
    var gender: DogGender?
    var vaccinations: [VaccinationItem] = []
    var isNeuteredOrSpayed: Bool?
    var allergiesAndFeedingInstructions: String?
    var profilePictureData: Data?
    var medications: [Medication] = []
    var scheduledMedications: [ScheduledMedication] = []
    var visitCount: Int = 0
    var lastVisitDate: Date?
    var isDeleted: Bool = false
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String?
    var lastModifiedBy: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String? = nil,
        ownerPhoneNumber: String? = nil,
        age: Int? = nil,
        gender: DogGender? = nil,
        vaccinations: [VaccinationItem] = [],
        isNeuteredOrSpayed: Bool? = nil,
        allergiesAndFeedingInstructions: String? = nil,
        profilePictureData: Data? = nil,
        medications: [Medication] = [],
        scheduledMedications: [ScheduledMedication] = [],
        visitCount: Int = 0,
        lastVisitDate: Date? = nil,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.ownerPhoneNumber = ownerPhoneNumber
        self.age = age
        self.gender = gender
        self.vaccinations = vaccinations
        self.isNeuteredOrSpayed = isNeuteredOrSpayed
        self.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
        self.profilePictureData = profilePictureData
        self.medications = medications
        self.scheduledMedications = scheduledMedications
        self.visitCount = visitCount
        self.lastVisitDate = lastVisitDate
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
    }
    
    // MARK: - Computed Properties
    
    var activeMedications: [Medication] {
        return medications.filter { $0.isActive }
    }
    
    var dailyMedications: [Medication] {
        return activeMedications.filter { $0.type == .daily }
    }
    
    var scheduledMedicationTypes: [Medication] {
        return activeMedications.filter { $0.type == .scheduled }
    }
    
    var pendingScheduledMedications: [ScheduledMedication] {
        return scheduledMedications.filter { $0.status == .pending }
    }
    
    var overdueScheduledMedications: [ScheduledMedication] {
        let now = Date()
        return scheduledMedications.filter { 
            $0.status == .pending && $0.scheduledDate < now 
        }
    }
    
    var todaysScheduledMedications: [ScheduledMedication] {
        let today = Date()
        let calendar = Calendar.current
        return scheduledMedications.filter { scheduledMed in
            calendar.isDate(scheduledMed.scheduledDate, inSameDayAs: today)
        }
    }
    
    var hasMedications: Bool {
        return !activeMedications.isEmpty
    }
    
    var hasScheduledMedications: Bool {
        return !scheduledMedications.isEmpty
    }
    
    var needsMedicationAttention: Bool {
        return !overdueScheduledMedications.isEmpty || !todaysScheduledMedications.isEmpty
    }
}

// MARK: - Helper Methods

extension PersistentDog {
    // Check if this dog is currently present based on visits
    func isCurrentlyPresentWithVisits(_ visits: [Visit]) -> Bool {
        // Find active visit for this dog
        return visits.contains { visit in
            visit.dogId == self.id && visit.isCurrentlyPresent
        }
    }
    
    // Get the current active visit for this dog
    func getCurrentVisit(from visits: [Visit]) -> Visit? {
        return visits.first { visit in
            visit.dogId == self.id && visit.isCurrentlyPresent
        }
    }
} 