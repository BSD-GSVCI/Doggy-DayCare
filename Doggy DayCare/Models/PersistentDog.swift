import Foundation

struct PersistentDog: Codable, Identifiable, Equatable {
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
    var visitCount: Int = 0
    var lastVisitDate: Date?
    var needsWalking: Bool = false
    var walkingNotes: String?
    var isDaycareFed: Bool = false
    var notes: String?
    var specialInstructions: String?
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
        visitCount: Int = 0,
        lastVisitDate: Date? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isDaycareFed: Bool = false,
        notes: String? = nil,
        specialInstructions: String? = nil,
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
        self.visitCount = visitCount
        self.lastVisitDate = lastVisitDate
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.isDaycareFed = isDaycareFed
        self.notes = notes
        self.specialInstructions = specialInstructions
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
    }
    
    // MARK: - Computed Properties
    // Medication properties now handled by Visit model
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