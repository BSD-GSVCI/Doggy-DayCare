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
    let medications: String?
    let specialInstructions: String?
    let allergiesAndFeedingInstructions: String?
    let needsWalking: Bool
    let walkingNotes: String?
    let isDaycareFed: Bool
    let notes: String?
    let age: Int?
    let gender: DogGender?
    let vaccinationEndDate: Date?
    let isNeuteredOrSpayed: Bool?
    let ownerPhoneNumber: String?
    let isArrivalTimeSet: Bool
    let visitCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(from dog: Dog, date: Date) {
        self.id = UUID()
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
        self.specialInstructions = dog.specialInstructions
        self.allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions
        self.needsWalking = dog.needsWalking
        self.walkingNotes = dog.walkingNotes
        self.isDaycareFed = dog.isDaycareFed
        self.notes = dog.notes
        self.age = dog.age
        self.gender = dog.gender
        self.vaccinationEndDate = dog.vaccinationEndDate
        self.isNeuteredOrSpayed = dog.isNeuteredOrSpayed
        self.ownerPhoneNumber = dog.ownerPhoneNumber
        self.isArrivalTimeSet = dog.isArrivalTimeSet
        self.visitCount = dog.visitCount
        self.createdAt = dog.createdAt
        self.updatedAt = dog.updatedAt
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