import Foundation

struct DogHistoryRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let dogId: UUID
    let dogName: String
    let ownerName: String?
    let profilePictureData: Data?
    let arrivalDate: Date
    let departureDate: Date?
    let isBoarding: Bool
    let boardingEndDate: Date?
    let isCurrentlyPresent: Bool
    let shouldBeTreatedAsDaycare: Bool
    let medications: [Medication]
    let scheduledMedications: [ScheduledMedication]
    let specialInstructions: String?
    let allergiesAndFeedingInstructions: String?
    let needsWalking: Bool
    let walkingNotes: String?
    let isDaycareFed: Bool
    let notes: String?
    let age: Int?
    let gender: DogGender?
    let vaccinations: [VaccinationItem]
    let isNeuteredOrSpayed: Bool?
    let ownerPhoneNumber: String?
    let isArrivalTimeSet: Bool
    let visitCount: Int
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool
    
    // Deterministic UUID for (dogId, date)
    static func deterministicId(dogId: UUID, date: Date) -> UUID {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let baseString = "\(dogId.uuidString)_\(dateString)"
        return UUID(uuidString: baseString.md5ToUUID()) ?? UUID()
    }
    
    init(from dog: DogWithVisit, date: Date) {
        self.date = date
        self.dogId = dog.id
        self.dogName = dog.name
        self.ownerName = dog.ownerName
        self.profilePictureData = dog.profilePictureData
        self.arrivalDate = dog.arrivalDate
        self.departureDate = dog.departureDate
        self.isBoarding = dog.isBoarding
        self.boardingEndDate = dog.boardingEndDate
        self.isCurrentlyPresent = dog.isCurrentlyPresent
        self.shouldBeTreatedAsDaycare = dog.shouldBeTreatedAsDaycare
        self.medications = dog.medications
        self.scheduledMedications = dog.scheduledMedications
        self.specialInstructions = dog.specialInstructions
        self.allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions
        self.needsWalking = dog.needsWalking
        self.walkingNotes = dog.walkingNotes
        self.isDaycareFed = dog.isDaycareFed
        self.notes = dog.notes
        self.age = dog.age
        self.gender = dog.gender
        self.vaccinations = dog.vaccinations
        self.isNeuteredOrSpayed = dog.isNeuteredOrSpayed
        self.ownerPhoneNumber = dog.ownerPhoneNumber
        self.isArrivalTimeSet = dog.isArrivalTimeSet
        self.visitCount = dog.visitCount
        self.createdAt = dog.createdAt
        self.updatedAt = dog.updatedAt
        self.isDeleted = dog.isDeleted
        self.id = DogHistoryRecord.deterministicId(dogId: dog.id, date: date)
    }
    
    init(id: UUID, from record: DogHistoryRecord, date: Date) {
        self.id = id
        self.date = date
        self.dogId = record.dogId
        self.dogName = record.dogName
        self.ownerName = record.ownerName
        self.profilePictureData = record.profilePictureData
        self.arrivalDate = record.arrivalDate
        self.departureDate = record.departureDate
        self.isBoarding = record.isBoarding
        self.boardingEndDate = record.boardingEndDate
        self.isCurrentlyPresent = record.isCurrentlyPresent
        self.shouldBeTreatedAsDaycare = record.shouldBeTreatedAsDaycare
        self.medications = record.medications
        self.scheduledMedications = record.scheduledMedications
        self.specialInstructions = record.specialInstructions
        self.allergiesAndFeedingInstructions = record.allergiesAndFeedingInstructions
        self.needsWalking = record.needsWalking
        self.walkingNotes = record.walkingNotes
        self.isDaycareFed = record.isDaycareFed
        self.notes = record.notes
        self.age = record.age
        self.gender = record.gender
        self.vaccinations = record.vaccinations
        self.isNeuteredOrSpayed = record.isNeuteredOrSpayed
        self.ownerPhoneNumber = record.ownerPhoneNumber
        self.isArrivalTimeSet = record.isArrivalTimeSet
        self.visitCount = record.visitCount
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.isDeleted = record.isDeleted
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy HH:mm"
        return formatter.string(from: arrivalDate)
    }
    
    var formattedDepartureTime: String? {
        guard let departureDate = departureDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy HH:mm"
        return formatter.string(from: departureDate)
    }
    
    var serviceType: String {
        if isBoarding {
            return "Boarding"
        } else {
            return "Daycare"
        }
    }
    
    var statusDescription: String {
        if isCurrentlyPresent {
            return "Present"
        } else if departureDate != nil {
            return "Departed"
        } else {
            return "Scheduled"
        }
    }
}

// MARK: - String MD5 to UUID Helper
extension String {
    func md5ToUUID() -> String {
        let md5 = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        let bytes = Array(md5.prefix(16))
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return uuidString
    }
}
import CryptoKit 