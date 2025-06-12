import Foundation
import SwiftData

struct PottyRecord: Codable {
    let timestamp: Date
    let type: PottyType
    
    enum PottyType: String, Codable {
        case pee
        case poop
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
    var id: UUID
    var name: String
    var arrivalDate: Date
    var departureDate: Date?
    var needsWalking: Bool
    var walkingNotes: String?
    var isBoarding: Bool
    var specialInstructions: String?
    var medications: String?
    var isDaycareFed: Bool
    var pottyRecords: [PottyRecord]
    var feedingRecords: [FeedingRecord]
    var medicationRecords: [MedicationRecord]
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        arrivalDate: Date,
        departureDate: Date? = nil,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        isBoarding: Bool = false,
        specialInstructions: String? = nil,
        medications: String? = nil,
        isDaycareFed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.isBoarding = isBoarding
        self.specialInstructions = specialInstructions
        self.medications = medications
        self.isDaycareFed = isDaycareFed
        self.pottyRecords = []
        self.feedingRecords = []
        self.medicationRecords = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func addPottyRecord(type: PottyRecord.PottyType) {
        let record = PottyRecord(timestamp: Date(), type: type)
        pottyRecords.append(record)
        updatedAt = Date()
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