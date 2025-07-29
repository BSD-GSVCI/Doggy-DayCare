// DEPRECATION NOTICE: WalkingRecord is now deprecated and should never be used anywhere in the codebase. There is no need to track walking separately, as all walking in a daycare business is for potty breaks and should be tracked with PottyRecords only. -- 2024
import Foundation

struct PottyRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: PottyType
    var notes: String?  // Add notes field
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
    
    init(timestamp: Date, type: PottyType, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.notes = notes
        self.recordedBy = recordedBy
    }
}

struct FeedingRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: FeedingType
    var notes: String?  // Add notes field
    var recordedBy: String?  // Store user name instead of User reference
    
    enum FeedingType: String, Codable {
        case breakfast
        case lunch
        case dinner
        case snack
    }
    
    init(timestamp: Date, type: FeedingType, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.notes = notes
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

// Enhanced medication models
struct Medication: Codable, Identifiable {
    var id = UUID()
    var name: String
    var type: MedicationType
    var notes: String?
    var isActive: Bool = true
    var createdAt: Date = Date()
    var createdBy: String?
    
    enum MedicationType: String, Codable, CaseIterable {
        case daily = "daily"
        case scheduled = "scheduled"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .scheduled: return "Scheduled"
            }
        }
    }
    
    init(name: String, type: MedicationType, notes: String? = nil, createdBy: String? = nil) {
        self.name = name
        self.type = type
        self.notes = notes
        self.createdBy = createdBy
    }
}

struct ScheduledMedication: Codable, Identifiable {
    var id = UUID()
    var medicationId: UUID
    var scheduledDate: Date
    var notificationTime: Date
    var status: ScheduledMedicationStatus = .pending
    var notes: String?
    var administeredAt: Date?
    var administeredBy: String?
    var createdAt: Date = Date()
    
    enum ScheduledMedicationStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case administered = "administered"
        case skipped = "skipped"
        case overdue = "overdue"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .administered: return "Administered"
            case .skipped: return "Skipped"
            case .overdue: return "Overdue"
            }
        }
        
        var color: String {
            switch self {
            case .pending: return "orange"
            case .administered: return "green"
            case .skipped: return "gray"
            case .overdue: return "red"
            }
        }
    }
    
    init(medicationId: UUID, scheduledDate: Date, notificationTime: Date, status: ScheduledMedicationStatus = .pending, notes: String? = nil) {
        self.medicationId = medicationId
        self.scheduledDate = scheduledDate
        self.notificationTime = notificationTime
        self.status = status
        self.notes = notes
    }
}

enum DogGender: String, Codable, CaseIterable, Identifiable {
    case male, female, unknown
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unknown: return "Unknown"
        }
    }
}

struct VaccinationItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var endDate: Date?
}

struct Dog: Codable, Identifiable {
    var id: UUID
    var name: String
    var ownerName: String?  // New field for dog owner's name
    var arrivalDate: Date
    var departureDate: Date?
    var isBoarding: Bool
    var boardingEndDate: Date?

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
    var isDeleted: Bool = false  // Track if dog is marked as deleted
    var age: Int?
    var gender: DogGender?
    var vaccinations: [VaccinationItem] = []
    var isNeuteredOrSpayed: Bool?
    var ownerPhoneNumber: String?
    
    // Records
    var feedingRecords: [FeedingRecord] = []
    var medicationRecords: [MedicationRecord] = []
    var pottyRecords: [PottyRecord] = []
    
    // Enhanced Medications
    var medications: [Medication] = []
    var scheduledMedications: [ScheduledMedication] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String? = nil,
        arrivalDate: Date,
        isBoarding: Bool = false,
        boardingEndDate: Date? = nil,
        specialInstructions: String? = nil,
        allergiesAndFeedingInstructions: String? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isDaycareFed: Bool = false,
        notes: String? = nil,
        profilePictureData: Data? = nil,
        isArrivalTimeSet: Bool = true,
        isDeleted: Bool = false,
        age: Int? = nil,
        gender: DogGender? = nil,
        vaccinations: [VaccinationItem] = [],
        isNeuteredOrSpayed: Bool? = nil,
        ownerPhoneNumber: String? = nil,
        medications: [Medication] = [],
        scheduledMedications: [ScheduledMedication] = []
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.arrivalDate = arrivalDate
        self.isBoarding = isBoarding
        self.boardingEndDate = boardingEndDate
        // Initialize medications as empty array - will be populated by new system
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
        self.isDeleted = isDeleted
        self.age = age
        self.gender = gender
        self.vaccinations = vaccinations
        self.isNeuteredOrSpayed = isNeuteredOrSpayed
        self.ownerPhoneNumber = ownerPhoneNumber
        self.medications = medications
        self.scheduledMedications = scheduledMedications
    }
    
    mutating func addPottyRecord(type: PottyRecord.PottyType, notes: String? = nil, recordedBy: User? = nil) {
        let record = PottyRecord(timestamp: Date(), type: type, notes: notes, recordedBy: recordedBy?.name)
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
    
    mutating func updatePottyRecord(at timestamp: Date, type: PottyRecord.PottyType, notes: String? = nil, modifiedBy: User? = nil) {
        if let index = pottyRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            pottyRecords[index].type = type
            pottyRecords[index].notes = notes
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func addFeedingRecord(type: FeedingRecord.FeedingType, notes: String? = nil, recordedBy: User? = nil) {
        let record = FeedingRecord(
            timestamp: Date(),
            type: type,
            notes: notes,
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
    
    mutating func updateFeedingRecord(at timestamp: Date, type: FeedingRecord.FeedingType, notes: String? = nil, modifiedBy: User? = nil) {
        if let index = feedingRecords.firstIndex(where: { $0.timestamp == timestamp }) {
            feedingRecords[index].type = type
            feedingRecords[index].notes = notes
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    mutating func addMedicationRecord(notes: String?, recordedBy: User? = nil) {
        print("🔄 Adding medication record for \(name)")
        print("📝 Notes: \(notes ?? "nil")")
        print("👤 Recorded by: \(recordedBy?.name ?? "nil")")
        
        let record = MedicationRecord(
            timestamp: Date(),
            notes: notes,
            recordedBy: recordedBy?.name
        )
        
        print("📋 Created medication record with notes: \(record.notes ?? "nil")")
        medicationRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("✅ Added medication record for \(name), total records: \(medicationRecords.count)")
        print("📝 Latest record notes: \(medicationRecords.last?.notes ?? "nil")")
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
    
    // MARK: - Enhanced Medication Management
    
    mutating func addMedication(_ medication: Medication, createdBy: User? = nil) {
        var newMedication = medication
        newMedication.createdBy = createdBy?.name
        medications.append(newMedication)
        updatedAt = Date()
        lastModifiedBy = createdBy
        print("✅ Added medication '\(medication.name)' for \(name)")
    }
    
    mutating func removeMedication(_ medication: Medication, modifiedBy: User? = nil) {
        medications.removeAll { $0.id == medication.id }
        // Also remove any scheduled medications for this medication
        scheduledMedications.removeAll { $0.medicationId == medication.id }
        updatedAt = Date()
        lastModifiedBy = modifiedBy
        print("✅ Removed medication '\(medication.name)' for \(name)")
    }
    
    mutating func updateMedication(_ medication: Medication, modifiedBy: User? = nil) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
            updatedAt = Date()
            lastModifiedBy = modifiedBy
            print("✅ Updated medication '\(medication.name)' for \(name)")
        }
    }
    
    mutating func addScheduledMedication(_ scheduledMedication: ScheduledMedication, createdBy: User? = nil) {
        scheduledMedications.append(scheduledMedication)
        updatedAt = Date()
        lastModifiedBy = createdBy
        print("✅ Added scheduled medication for \(name) on \(scheduledMedication.scheduledDate)")
    }
    
    mutating func updateScheduledMedicationStatus(_ scheduledMedication: ScheduledMedication, status: ScheduledMedication.ScheduledMedicationStatus, administeredBy: User? = nil) {
        if let index = scheduledMedications.firstIndex(where: { $0.id == scheduledMedication.id }) {
            scheduledMedications[index].status = status
            if status == .administered {
                scheduledMedications[index].administeredAt = Date()
                scheduledMedications[index].administeredBy = administeredBy?.name
            }
            updatedAt = Date()
            lastModifiedBy = administeredBy
            print("✅ Updated scheduled medication status to \(status.displayName) for \(name)")
        }
    }
    
    mutating func removeScheduledMedication(_ scheduledMedication: ScheduledMedication, modifiedBy: User? = nil) {
        scheduledMedications.removeAll { $0.id == scheduledMedication.id }
        updatedAt = Date()
        lastModifiedBy = modifiedBy
        print("✅ Removed scheduled medication for \(name)")
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
        
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: arrivalDate, to: departureDate)
        if let days = components.day, let hours = components.hour, let minutes = components.minute {
            // Ensure we have valid non-negative values
            let safeDays = max(0, days)
            let safeHours = max(0, hours)
            let safeMinutes = max(0, minutes)
            
            if safeDays > 0 {
                return "\(safeDays)d \(safeHours)h \(safeMinutes)m"
            } else if safeHours > 0 {
                return "\(safeHours)h \(safeMinutes)m"
            } else {
                return "\(safeMinutes)m"
            }
        }
        return ""
    }
    
    var formattedCurrentStayDuration: String {
        let endDate = Date()
        
        // Ensure endDate is after arrivalDate to prevent negative durations
        guard endDate > arrivalDate else { return "" }
        
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: arrivalDate, to: endDate)
        if let days = components.day, let hours = components.hour, let minutes = components.minute {
            // Ensure we have valid non-negative values
            let safeDays = max(0, days)
            let safeHours = max(0, hours)
            let safeMinutes = max(0, minutes)
            
            if safeDays > 0 {
                return "\(safeDays)d \(safeHours)h \(safeMinutes)m"
            } else if safeHours > 0 {
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
        let count = pottyRecords.filter { $0.type == .pee || $0.type == .both }.count
        print("peeCount for \(name): \(count) (total records: \(pottyRecords.count))")
        return count
    }
    
    var poopCount: Int {
        let count = pottyRecords.filter { $0.type == .poop || $0.type == .both }.count
        print("poopCount for \(name): \(count) (total records: \(pottyRecords.count))")
        return count
    }
    
    // MARK: - Enhanced Medication Computed Properties
    
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
        return !pendingScheduledMedications.isEmpty || !overdueScheduledMedications.isEmpty
    }
} 