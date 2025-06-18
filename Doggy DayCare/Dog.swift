import Foundation
import SwiftData

@Model
final class WalkingRecord {
    var timestamp: Date
    var notes: String?
    var recordedBy: String?  // Store user name instead of User reference
    
    init(timestamp: Date, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.notes = notes
        self.recordedBy = recordedBy
    }
}

@Model
final class PottyRecord {
    var timestamp: Date
    var type: PottyType
    var recordedBy: String?  // Store user name instead of User reference
    
    // Inverse relationship to Dog
    @Relationship(inverse: \Dog.pottyRecords)
    var dog: Dog?
    
    enum PottyType: String, Codable {
        case pee
        case poop
        case both
        case nothing
    }
    
    init(timestamp: Date, type: PottyType, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.recordedBy = recordedBy
    }
}

@Model
final class FeedingRecord {
    var timestamp: Date
    var type: FeedingType
    var recordedBy: String?  // Store user name instead of User reference
    
    // Inverse relationship to Dog
    @Relationship(inverse: \Dog.feedingRecords)
    var dog: Dog?
    
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

@Model
final class MedicationRecord {
    var timestamp: Date
    var notes: String?
    var recordedBy: String?  // Store user name instead of User reference
    
    // Inverse relationship to Dog
    @Relationship(inverse: \Dog.medicationRecords)
    var dog: Dog?
    
    init(timestamp: Date, notes: String? = nil, recordedBy: String? = nil) {
        self.timestamp = timestamp
        self.notes = notes
        self.recordedBy = recordedBy
    }
}

@Model
final class Dog: Codable {
    var id: UUID
    var name: String
    var arrivalDate: Date
    var departureDate: Date?
    var isBoarding: Bool
    var boardingEndDate: Date?
    var medications: String?
    var specialInstructions: String?
    var needsWalking: Bool
    var walkingNotes: String?
    var isDaycareFed: Bool
    var notes: String?
    var updatedAt: Date
    var createdAt: Date
    var createdBy: User?
    var lastModifiedBy: User?
    
    // Records
    @Relationship(deleteRule: .cascade)
    var feedingRecords: [FeedingRecord] = []
    
    @Relationship(deleteRule: .cascade)
    var medicationRecords: [MedicationRecord] = []
    
    @Relationship(deleteRule: .cascade)
    var pottyRecords: [PottyRecord] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        arrivalDate: Date,
        isBoarding: Bool = false,
        medications: String? = nil,
        specialInstructions: String? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isDaycareFed: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.arrivalDate = arrivalDate
        self.isBoarding = isBoarding
        self.medications = medications
        self.specialInstructions = specialInstructions
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.isDaycareFed = isDaycareFed
        self.notes = notes
        self.updatedAt = Date()
        self.createdAt = Date()
        self.createdBy = nil
        self.lastModifiedBy = nil
    }
    
    func addPottyRecord(type: PottyRecord.PottyType, recordedBy: User? = nil) {
        let record = PottyRecord(timestamp: Date(), type: type, recordedBy: recordedBy?.name)
        pottyRecords.append(record)
        updatedAt = Date()
        lastModifiedBy = recordedBy
        print("Added potty record for \(name), total records: \(pottyRecords.count)")
    }
    
    func removePottyRecord(at timestamp: Date, modifiedBy: User? = nil) {
        if pottyRecords.contains(where: { $0.timestamp == timestamp }) {
            pottyRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    func updatePottyRecord(at timestamp: Date, type: PottyRecord.PottyType, modifiedBy: User? = nil) {
        if let record = pottyRecords.first(where: { $0.timestamp == timestamp }) {
            record.type = type
            updatedAt = Date()
            lastModifiedBy = modifiedBy
        }
    }
    
    func addFeedingRecord(type: FeedingRecord.FeedingType, recordedBy: User? = nil) {
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
    
    func addMedicationRecord(notes: String?, recordedBy: User? = nil) {
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
    
    func recordStatusChange(_ field: String, newValue: Bool) {
        updatedAt = Date()
        // In a real app, you might want to log this to a change history
        print("\(field) changed to \(newValue)")
    }
    
    private func recordChange(_ change: String) {
        updatedAt = Date()
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
    
    var isCurrentlyPresent: Bool {
        let calendar = Calendar.current
        let hasArrived = calendar.dateComponents([.hour, .minute], from: arrivalDate).hour != 0 ||
                        calendar.dateComponents([.hour, .minute], from: arrivalDate).minute != 0
        return hasArrived && departureDate == nil
    }
    
    var stayDuration: TimeInterval {
        let endDate = departureDate ?? Date()
        return endDate.timeIntervalSince(arrivalDate)
    }
    
    var formattedStayDuration: String {
        guard let departureDate = departureDate else { return "" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: arrivalDate, to: departureDate)
        if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        return ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, arrivalDate, departureDate, isBoarding, boardingEndDate
        case medications, specialInstructions, needsWalking, walkingNotes
        case isDaycareFed, notes, updatedAt, createdAt
        case feedingRecords, medicationRecords, pottyRecords
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        let id = UUID(uuidString: idString) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let arrivalDate = try container.decode(Date.self, forKey: .arrivalDate)
        let isBoarding = try container.decode(Bool.self, forKey: .isBoarding)
        let medications = try container.decodeIfPresent(String.self, forKey: .medications)
        let specialInstructions = try container.decodeIfPresent(String.self, forKey: .specialInstructions)
        let needsWalking = try container.decode(Bool.self, forKey: .needsWalking)
        let walkingNotes = try container.decodeIfPresent(String.self, forKey: .walkingNotes)
        let isDaycareFed = try container.decode(Bool.self, forKey: .isDaycareFed)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        self.init(
            id: id,
            name: name,
            arrivalDate: arrivalDate,
            isBoarding: isBoarding,
            medications: medications,
            specialInstructions: specialInstructions,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes
        )
        
        // Decode optional properties
        self.departureDate = try container.decodeIfPresent(Date.self, forKey: .departureDate)
        self.boardingEndDate = try container.decodeIfPresent(Date.self, forKey: .boardingEndDate)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode relationships
        self.feedingRecords = try container.decode([FeedingRecord].self, forKey: .feedingRecords)
        self.medicationRecords = try container.decode([MedicationRecord].self, forKey: .medicationRecords)
        self.pottyRecords = try container.decode([PottyRecord].self, forKey: .pottyRecords)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(arrivalDate, forKey: .arrivalDate)
        try container.encode(isBoarding, forKey: .isBoarding)
        try container.encodeIfPresent(medications, forKey: .medications)
        try container.encodeIfPresent(specialInstructions, forKey: .specialInstructions)
        try container.encode(needsWalking, forKey: .needsWalking)
        try container.encodeIfPresent(walkingNotes, forKey: .walkingNotes)
        try container.encode(isDaycareFed, forKey: .isDaycareFed)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(departureDate, forKey: .departureDate)
        try container.encodeIfPresent(boardingEndDate, forKey: .boardingEndDate)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(feedingRecords, forKey: .feedingRecords)
        try container.encode(medicationRecords, forKey: .medicationRecords)
        try container.encode(pottyRecords, forKey: .pottyRecords)
    }
}

extension WalkingRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, notes, recordedBy
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let recordedBy = try container.decodeIfPresent(String.self, forKey: .recordedBy)
        self.init(timestamp: timestamp, notes: notes, recordedBy: recordedBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(recordedBy, forKey: .recordedBy)
    }
}

extension FeedingRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, type, recordedBy
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let type = try container.decode(FeedingType.self, forKey: .type)
        let recordedBy = try container.decodeIfPresent(String.self, forKey: .recordedBy)
        self.init(timestamp: timestamp, type: type, recordedBy: recordedBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(recordedBy, forKey: .recordedBy)
    }
}

extension MedicationRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, notes, recordedBy
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let recordedBy = try container.decodeIfPresent(String.self, forKey: .recordedBy)
        self.init(timestamp: timestamp, notes: notes, recordedBy: recordedBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(recordedBy, forKey: .recordedBy)
    }
}

extension PottyRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, type, recordedBy
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let type = try container.decode(PottyType.self, forKey: .type)
        let recordedBy = try container.decodeIfPresent(String.self, forKey: .recordedBy)
        self.init(timestamp: timestamp, type: type, recordedBy: recordedBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(recordedBy, forKey: .recordedBy)
    }
} 