import Foundation
import SwiftData

@Model
final class PottyRecord {
    var timestamp: Date
    var type: PottyType
    
    enum PottyType: String, Codable {
        case pee
        case poop
    }
    
    init(timestamp: Date, type: PottyType) {
        self.timestamp = timestamp
        self.type = type
    }
}

struct FeedingRecord: Codable {
    let timestamp: Date
    let type: FeedingType
    
    enum FeedingType: String, Codable {
        case breakfast
        case lunch
        case dinner
        case snack
    }
}

struct MedicationRecord: Codable {
    let timestamp: Date
    let notes: String?
}

@Model
final class Dog: Identifiable {
    @Transient private var modelContext: ModelContext?
    
    var id: UUID
    var name: String
    var arrivalDate: Date
    var departureDate: Date?
    var boardingEndDate: Date?
    var isBoarding: Bool
    var isDaycareFed: Bool
    var needsWalking: Bool
    var walkingNotes: String?
    var specialInstructions: String?
    var medications: String?
    var notes: String?
    var feedingRecords: [FeedingRecord]
    var medicationRecords: [MedicationRecord]
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade) var pottyRecords: [PottyRecord]
    
    init(
        id: UUID = UUID(),
        name: String,
        arrivalDate: Date,
        departureDate: Date? = nil,
        boardingEndDate: Date? = nil,
        isBoarding: Bool = false,
        isDaycareFed: Bool = false,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        specialInstructions: String? = nil,
        medications: String? = nil,
        notes: String? = nil,
        modelContext: ModelContext? = nil
    ) {
        self.id = id
        self.name = name
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.boardingEndDate = boardingEndDate
        self.isBoarding = isBoarding
        self.isDaycareFed = isDaycareFed
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.specialInstructions = specialInstructions
        self.medications = medications
        self.notes = notes
        self.feedingRecords = []
        self.medicationRecords = []
        self.pottyRecords = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func addPottyRecord(type: PottyRecord.PottyType) {
        guard let context = modelContext else { return }
        let record = PottyRecord(timestamp: Date(), type: type)
        context.insert(record)
        pottyRecords.append(record)
        updatedAt = Date()
        try? context.save()
    }
    
    func removePottyRecord(at timestamp: Date) {
        guard let context = modelContext else { return }
        if let record = pottyRecords.first(where: { $0.timestamp == timestamp }) {
            context.delete(record)
            pottyRecords.removeAll { $0.timestamp == timestamp }
            updatedAt = Date()
            try? context.save()
        }
    }
    
    func updatePottyRecord(at timestamp: Date, type: PottyRecord.PottyType) {
        guard let context = modelContext else { return }
        if let record = pottyRecords.first(where: { $0.timestamp == timestamp }) {
            record.type = type
            updatedAt = Date()
            try? context.save()
        }
    }
    
    func addFeedingRecord(type: FeedingRecord.FeedingType) {
        let record = FeedingRecord(timestamp: Date(), type: type)
        feedingRecords.append(record)
        updatedAt = Date()
    }
    
    func addMedicationRecord(notes: String? = nil) {
        let record = MedicationRecord(timestamp: Date(), notes: notes)
        medicationRecords.append(record)
        updatedAt = Date()
    }
    
    var peeCount: Int {
        pottyRecords.filter { $0.type == .pee }.count
    }
    
    var poopCount: Int {
        pottyRecords.filter { $0.type == .poop }.count
    }
    
    var breakfastCount: Int {
        feedingRecords.filter { $0.type == .breakfast }.count
    }
    
    var lunchCount: Int {
        feedingRecords.filter { $0.type == .lunch }.count
    }
    
    var dinnerCount: Int {
        feedingRecords.filter { $0.type == .dinner }.count
    }
    
    var snackCount: Int {
        feedingRecords.filter { $0.type == .snack }.count
    }
    
    var medicationCount: Int {
        medicationRecords.count
    }
    
    var isCurrentlyPresent: Bool {
        guard let departureDate = departureDate else { return true }
        return Date() < departureDate
    }
    
    var stayDuration: TimeInterval {
        let endDate = departureDate ?? Date()
        return endDate.timeIntervalSince(arrivalDate)
    }
    
    var formattedStayDuration: String {
        let duration = stayDuration
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h \(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
} 