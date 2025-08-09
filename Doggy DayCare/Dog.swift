// DEPRECATED DOG MODEL REMOVED
// This file now only contains the supporting models that are used by both PersistentDog and Visit
// The legacy Dog struct has been completely removed as part of the migration to PersistentDog + Visit model

import Foundation

struct PottyRecord: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: PottyType
    var notes: String?
    var recordedBy: String?
    
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
                #if DEBUG
                print("⚠️ Unknown PottyType value: \(rawValue), defaulting to pee")
                #endif
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
    var notes: String?
    var recordedBy: String?
    
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
    var recordedBy: String?
    
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