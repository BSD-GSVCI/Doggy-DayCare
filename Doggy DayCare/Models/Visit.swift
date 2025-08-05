import Foundation

struct Visit: Codable, Identifiable {
    let id: UUID
    let dogId: UUID // Reference to PersistentDog
    var arrivalDate: Date
    var departureDate: Date?
    var isBoarding: Bool
    var boardingEndDate: Date?
    var isDaycareFed: Bool
    var notes: String?
    var specialInstructions: String?
    var needsWalking: Bool
    var walkingNotes: String?
    var isDeleted: Bool = false
    var deletedAt: Date?
    var deletedBy: String?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String?
    var lastModifiedBy: String?
    
    // Visit-specific activity records
    var feedingRecords: [FeedingRecord] = []
    var medicationRecords: [MedicationRecord] = []
    var pottyRecords: [PottyRecord] = []
    
    init(
        id: UUID = UUID(),
        dogId: UUID,
        arrivalDate: Date,
        departureDate: Date? = nil,
        isBoarding: Bool = false,
        boardingEndDate: Date? = nil,
        isDaycareFed: Bool = false,
        notes: String? = nil,
        specialInstructions: String? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        deletedBy: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil,
        feedingRecords: [FeedingRecord] = [],
        medicationRecords: [MedicationRecord] = [],
        pottyRecords: [PottyRecord] = []
    ) {
        self.id = id
        self.dogId = dogId
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.isBoarding = isBoarding
        self.boardingEndDate = boardingEndDate
        self.isDaycareFed = isDaycareFed
        self.notes = notes
        self.specialInstructions = specialInstructions
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.feedingRecords = feedingRecords
        self.medicationRecords = medicationRecords
        self.pottyRecords = pottyRecords
    }
    
    // MARK: - Computed Properties
    
    var isCurrentlyPresent: Bool {
        let now = Date()
        let calendar = Calendar.current
        let hasArrived = calendar.isDate(arrivalDate, inSameDayAs: now) || arrivalDate < now
        return hasArrived && departureDate == nil && !isDeleted
    }
    
    var shouldBeTreatedAsDaycare: Bool {
        // A boarding dog should be treated as daycare if their boarding end date has arrived
        // This means they're effectively a daycare dog for their final day
        guard isBoarding, let boardingEndDate = boardingEndDate else {
            // If not boarding or no boarding end date, treat as normal
            return !isBoarding
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // If boarding end date is today or in the past, treat as daycare
        return calendar.isDate(boardingEndDate, inSameDayAs: now) || boardingEndDate < now
    }
    
    var feedingCount: Int {
        return feedingRecords.count
    }
    
    var medicationCount: Int {
        return medicationRecords.count
    }
    
    var peeCount: Int {
        return pottyRecords.filter { $0.type == .pee || $0.type == .both }.count
    }
    
    var poopCount: Int {
        return pottyRecords.filter { $0.type == .poop || $0.type == .both }.count
    }
    
    var formattedStayDuration: String {
        guard let departureDate = departureDate else {
            return "Currently present"
        }
        
        let duration = departureDate.timeIntervalSince(arrivalDate)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedCurrentStayDuration: String {
        let duration = Date().timeIntervalSince(arrivalDate)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Record Management
    
    mutating func addPottyRecord(type: PottyRecord.PottyType, notes: String? = nil, recordedBy: String? = nil) {
        let record = PottyRecord(timestamp: Date(), type: type, notes: notes, recordedBy: recordedBy)
        pottyRecords.append(record)
        updatedAt = Date()
    }
    
    mutating func removePottyRecord(at timestamp: Date) {
        pottyRecords.removeAll { $0.timestamp == timestamp }
        updatedAt = Date()
    }
    
    mutating func updatePottyRecord(at timestamp: Date, type: PottyRecord.PottyType, notes: String? = nil) {
        if let index = pottyRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            pottyRecords[index].type = type
            pottyRecords[index].notes = notes
            updatedAt = Date()
        }
    }
    
    mutating func addFeedingRecord(type: FeedingRecord.FeedingType, notes: String? = nil, recordedBy: String? = nil) {
        let record = FeedingRecord(timestamp: Date(), type: type, notes: notes, recordedBy: recordedBy)
        feedingRecords.append(record)
        updatedAt = Date()
    }
    
    mutating func removeFeedingRecord(at timestamp: Date) {
        feedingRecords.removeAll { $0.timestamp == timestamp }
        updatedAt = Date()
    }
    
    mutating func updateFeedingRecord(at timestamp: Date, type: FeedingRecord.FeedingType, notes: String? = nil) {
        if let index = feedingRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            feedingRecords[index].type = type
            feedingRecords[index].notes = notes
            updatedAt = Date()
        }
    }
    
    mutating func addMedicationRecord(notes: String? = nil, recordedBy: String? = nil) {
        let record = MedicationRecord(timestamp: Date(), notes: notes, recordedBy: recordedBy)
        medicationRecords.append(record)
        updatedAt = Date()
    }
    
    mutating func removeMedicationRecord(at timestamp: Date) {
        medicationRecords.removeAll { $0.timestamp == timestamp }
        updatedAt = Date()
    }
    
    mutating func updateMedicationRecord(at timestamp: Date, notes: String? = nil) {
        if let index = medicationRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            medicationRecords[index].notes = notes
            updatedAt = Date()
        }
    }
}

// MARK: - Helper Methods

extension Visit {
    // Get feeding counts by type
    var breakfastCount: Int {
        return feedingRecords.filter { $0.type == .breakfast }.count
    }
    
    var lunchCount: Int {
        return feedingRecords.filter { $0.type == .lunch }.count
    }
    
    var dinnerCount: Int {
        return feedingRecords.filter { $0.type == .dinner }.count
    }
    
    var snackCount: Int {
        return feedingRecords.filter { $0.type == .snack }.count
    }
} 