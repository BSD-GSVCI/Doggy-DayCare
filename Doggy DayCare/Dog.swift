import Foundation

struct WalkingRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var notes: String?
    var recordedBy: String?  // Store user name instead of User reference
    
    init(timestamp: Date, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.notes = notes
        self.recordedBy = recordedBy
    }
}

struct PottyRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: PottyType
    var recordedBy: String?  // Store user name instead of User reference
    
    enum PottyType: String, Codable {
        case pee
        case poop
        case both
        case nothing
        
        // Safe initializer to handle invalid enum values
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            
            // Handle migration from old enum values
            switch rawValue {
            case "pee", "Pee", "PEE":
                self = .pee
            case "poop", "Poop", "POOP":
                self = .poop
            case "both", "Both", "BOTH":
                self = .both
            case "nothing", "Nothing", "NOTHING":
                self = .nothing
            default:
                // Fallback to pee for any unrecognized values
                print("⚠️ Unknown PottyType value: \(rawValue), defaulting to pee")
                self = .pee
            }
        }
    }
    
    init(timestamp: Date, type: PottyType, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.recordedBy = recordedBy
    }
}

struct FeedingRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: FeedingType
    var recordedBy: String?  // Store user name instead of User reference
    
    enum FeedingType: String, Codable {
        case breakfast
        case lunch
        case dinner
        case snack
    }
    
    init(timestamp: Date, type: FeedingType, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.recordedBy = recordedBy
    }
}

struct MedicationRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var notes: String?
    var recordedBy: String?  // Store user name instead of User reference
    
    init(timestamp: Date, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.notes = notes
        self.recordedBy = recordedBy
    }
}

struct Dog: Codable, Identifiable {
    var id: UUID
    var name: String
    var ownerName: String?  // New field for dog owner's name
    var arrivalDate: Date
    var departureDate: Date?
    var isBoarding: Bool
    var boardingEndDate: Date?
    var medications: String?
    var specialInstructions: String?
    var allergiesAndFeedingInstructions: String?  // New field for allergies and feeding instructions
    var needsWalking: Bool
    var walkingNotes: String?
    var isDaycareFed: Bool
    var notes: String?
    var profilePictureData: Data?  // New field for profile picture
    var updatedAt: Date
    var createdAt: Date
    var createdBy: User?
    var lastModifiedBy: User?
    var visitCount: Int = 1  // Track total visits for this dog
    var isArrivalTimeSet: Bool = true  // Track if arrival time has been set
    
    // Records
    var feedingRecords: [FeedingRecord] = []
    var medicationRecords: [MedicationRecord] = []
    var pottyRecords: [PottyRecord] = []
    var walkingRecords: [WalkingRecord] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String? = nil,
        arrivalDate: Date,
        isBoarding: Bool = false,
        medications: String? = nil,
        specialInstructions: String? = nil,
        allergiesAndFeedingInstructions: String? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isDaycareFed: Bool = false,
        notes: String? = nil,
        profilePictureData: Data? = nil,
        isArrivalTimeSet: Bool = true
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.arrivalDate = arrivalDate
        self.isBoarding = isBoarding
        self.medications = medications
        self.specialInstructions = specialInstructions
        self.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.isDaycareFed = isDaycareFed
        self.notes = notes
        self.profilePictureData = profilePictureData
        self.updatedAt = Date()
        self.createdAt = Date()
        self.createdBy = nil
        self.lastModifiedBy = nil
        self.isArrivalTimeSet = isArrivalTimeSet
    }
    
    mutating func addPottyRecord(type: PottyRecord.PottyType, recordedBy: User? = nil) {
        let record = PottyRecord(timestamp: Date(), type: type, recordedBy: recordedBy?.name)
        pottyRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("Added potty record for \(name), total records: \(pottyRecords.count)")
    }
    
    mutating func removePottyRecord(at timestamp: Date, modifiedBy: User? = nil) {
        if pottyRecords.contains(where: { $0.timestamp == timestamp }) {
            pottyRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func updatePottyRecord(at timestamp: Date, type: PottyRecord.PottyType, modifiedBy: User? = nil) {
        if let index = pottyRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            pottyRecords[index].type = type
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func addFeedingRecord(type: FeedingRecord.FeedingType, recordedBy: User? = nil) {
        let record = FeedingRecord(
            timestamp: Date(),
            type: type,
            recordedBy: recordedBy?.name
        )
        feedingRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("Added feeding record for \(name), total records: \(feedingRecords.count)")
    }
    
    mutating func removeFeedingRecord(at timestamp: Date, modifiedBy: User? = nil) {
        if feedingRecords.contains(where: { $0.timestamp == timestamp }) {
            feedingRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func updateFeedingRecord(at timestamp: Date, type: FeedingRecord.FeedingType, modifiedBy: User? = nil) {
        if let index = feedingRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            feedingRecords[index].type = type
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func addMedicationRecord(notes: String?, recordedBy: User? = nil) {
        let record = MedicationRecord(
            timestamp: Date(),
            notes: notes,
            recordedBy: recordedBy?.name
        )
        medicationRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("Added medication record for \(name), total records: \(medicationRecords.count)")
    }
    
    mutating func removeMedicationRecord(at timestamp: Date, modifiedBy: User? = nil) {
        if medicationRecords.contains(where: { $0.timestamp == timestamp }) {
            medicationRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func updateMedicationRecord(at timestamp: Date, notes: String?, modifiedBy: User? = nil) {
        if let index = medicationRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            medicationRecords[index].notes = notes
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func addWalkingRecord(notes: String?, recordedBy: User? = nil) {
        let record = WalkingRecord(
            timestamp: Date(),
            notes: notes,
            recordedBy: recordedBy?.name
        )
        walkingRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("Added walking record for \(name), total records: \(walkingRecords.count)")
    }
    
    mutating func removeWalkingRecord(at timestamp: Date, modifiedBy: User? = nil) {
        if walkingRecords.contains(where: { $0.timestamp == timestamp }) {
            walkingRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func updateWalkingRecord(at timestamp: Date, notes: String?, modifiedBy: User? = nil) {
        if let index = walkingRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            walkingRecords[index].notes = notes
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    // MARK: - Computed Properties
    
    var isCurrentlyPresent: Bool {
        // A dog is currently present if they have arrived (arrivalDate is in the past or today)
        // and haven't departed yet (departureDate is nil)
        let now = Date()
        let calendar = Calendar.current
        
        // Check if arrival date is today or in the past
        let hasArrived = calendar.isDate(arrivalDate, inSameDayAs: now) || arrivalDate < now
        
        // Dog is present if they've arrived and haven't departed
        return hasArrived && departureDate == nil
    }
    
    var stayDuration: TimeInterval {
        let endDate = departureDate ?? Date()
        
        // Ensure endDate is after arrivalDate to prevent negative durations
        guard endDate > arrivalDate else { return 0 }
        
        return endDate.timeIntervalSince(arrivalDate)
    }
    
    var formattedStayDuration: String {
        guard let departureDate = departureDate else { return "" }
        
        // Ensure departureDate is after arrivalDate to prevent negative durations
        guard departureDate > arrivalDate else { return "" }
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: arrivalDate, to: departureDate)
        if let hours = components.hour, let minutes = components.minute {
            // Ensure we have valid non-negative values
            let safeHours = max(0, hours)
            let safeMinutes = max(0, minutes)
            
            if safeHours > 0 {
                return "\(safeHours)h \(safeMinutes)m"
            } else {
                return "\(safeMinutes)m"
            }
        }
        return ""
    }
    
    var breakfastCount: Int {
        let count = feedingRecords.filter { $0.type == .breakfast }.count
        print("breakfastCount for \(name): \(count) (total records: \(feedingRecords.count))")
        return count
    }
    
    var lunchCount: Int {
        let count = feedingRecords.filter { $0.type == .lunch }.count
        print("lunchCount for \(name): \(count) (total records: \(feedingRecords.count))")
        return count
    }
    
    var dinnerCount: Int {
        let count = feedingRecords.filter { $0.type == .dinner }.count
        print("dinnerCount for \(name): \(count) (total records: \(feedingRecords.count))")
        return count
    }
    
    var snackCount: Int {
        let count = feedingRecords.filter { $0.type == .snack }.count
        print("snackCount for \(name): \(count) (total records: \(feedingRecords.count))")
        return count
    }
    
    var medicationCount: Int {
        let count = medicationRecords.count
        print("medicationCount for \(name): \(count) (total records: \(medicationRecords.count))")
        return count
    }
    
    var peeCount: Int {
        let count = pottyRecords.filter { $0.type == .pee }.count
        print("peeCount for \(name): \(count) (total records: \(pottyRecords.count))")
        return count
    }
    
    var poopCount: Int {
        let count = pottyRecords.filter { $0.type == .poop }.count
        print("poopCount for \(name): \(count) (total records: \(pottyRecords.count))")
        return count
    }
} 