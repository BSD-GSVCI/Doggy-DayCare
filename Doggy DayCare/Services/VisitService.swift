import CloudKit
import Foundation

@MainActor
class VisitService: ObservableObject {
    static let shared = VisitService()
    
    private let container = CKContainer(identifier: "iCloud.GreenHouse.Doggy-DayCare")
    private let publicDatabase: CKDatabase
    
    // Record type names
    struct RecordTypes {
        static let visit = "Visit"
    }
    
    // Field names for Visit
    struct VisitFields {
        static let id = "id"
        static let dogId = "dogId"
        static let arrivalDate = "arrivalDate"
        static let departureDate = "departureDate"
        static let isBoarding = "isBoarding"
        static let boardingEndDate = "boardingEndDate"
        static let isDeleted = "isDeleted"
        static let deletedAt = "deletedAt"
        static let deletedBy = "deletedBy"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let createdBy = "createdBy"
        static let lastModifiedBy = "lastModifiedBy"
        // Individual feeding record fields
        static let feedingTimestamps = "feedingTimestamps"
        static let feedingTypes = "feedingTypes"
        static let feedingNotes = "feedingNotes"
        static let feedingRecordedBy = "feedingRecordedBy"
        static let feedingIds = "feedingIds"
        
        // Individual potty record fields
        static let pottyTimestamps = "pottyTimestamps"
        static let pottyTypes = "pottyTypes"
        static let pottyNotes = "pottyNotes"
        static let pottyRecordedBy = "pottyRecordedBy"
        static let pottyIds = "pottyIds"
        
        // Individual medication record fields
        static let medicationRecordTimestamps = "medicationRecordTimestamps"
        static let medicationRecordNotes = "medicationRecordNotes"
        static let medicationRecordRecordedBy = "medicationRecordRecordedBy"
        static let medicationRecordIds = "medicationRecordIds"
        // Individual medication fields (matching CloudKit schema)
        static let medicationNames = "medicationNames"
        static let medicationTypes = "medicationTypes"
        static let medicationNotes = "medicationNotes"
        static let medicationIds = "medicationIds"
        static let scheduledMedicationDates = "scheduledMedicationDates"
        static let scheduledMedicationStatuses = "scheduledMedicationStatuses"
        static let scheduledMedicationNotes = "scheduledMedicationNotes"
        static let scheduledMedicationIds = "scheduledMedicationIds"
        static let scheduledMedicationNotificationTimes = "scheduledMedicationNotificationTimes"
    }
    
    private init() {
        self.publicDatabase = container.publicCloudDatabase
        #if DEBUG
        print("🔧 VisitService initialized")
        #endif
    }
    
    // MARK: - CRUD Operations
    
    func createVisit(_ visit: Visit) async throws {
        #if DEBUG
        print("📝 Creating visit for dog: \(visit.dogId)")
        #endif
        
        let record = CKRecord(recordType: RecordTypes.visit)
        
        // Set basic fields
        record[VisitFields.id] = visit.id.uuidString
        record[VisitFields.dogId] = visit.dogId.uuidString
        record[VisitFields.arrivalDate] = visit.arrivalDate
        record[VisitFields.departureDate] = visit.departureDate
        record[VisitFields.isBoarding] = visit.isBoarding ? 1 : 0
        record[VisitFields.boardingEndDate] = visit.boardingEndDate
        record[VisitFields.isDeleted] = visit.isDeleted ? 1 : 0
        record[VisitFields.deletedAt] = visit.deletedAt
        record[VisitFields.deletedBy] = visit.deletedBy
        record[VisitFields.createdAt] = visit.createdAt
        record[VisitFields.updatedAt] = visit.updatedAt
        record[VisitFields.createdBy] = visit.createdBy
        record[VisitFields.lastModifiedBy] = visit.lastModifiedBy
        
        // Set feeding records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.feedingRecords.isEmpty {
            let feedingTimestamps = visit.feedingRecords.map { $0.timestamp }
            let feedingTypes = visit.feedingRecords.map { $0.type.rawValue }
            let feedingNotes = visit.feedingRecords.map { $0.notes ?? "" }
            let feedingRecordedBy = visit.feedingRecords.map { $0.recordedBy ?? "" }
            let feedingIds = visit.feedingRecords.map { $0.id.uuidString }
            
            record[VisitFields.feedingTimestamps] = feedingTimestamps
            record[VisitFields.feedingTypes] = feedingTypes
            record[VisitFields.feedingNotes] = feedingNotes
            record[VisitFields.feedingRecordedBy] = feedingRecordedBy
            record[VisitFields.feedingIds] = feedingIds
        }
        
        // Set potty records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.pottyRecords.isEmpty {
            let pottyTimestamps = visit.pottyRecords.map { $0.timestamp }
            let pottyTypes = visit.pottyRecords.map { $0.type.rawValue }
            let pottyNotes = visit.pottyRecords.map { $0.notes ?? "" }
            let pottyRecordedBy = visit.pottyRecords.map { $0.recordedBy ?? "" }
            let pottyIds = visit.pottyRecords.map { $0.id.uuidString }
            
            record[VisitFields.pottyTimestamps] = pottyTimestamps
            record[VisitFields.pottyTypes] = pottyTypes
            record[VisitFields.pottyNotes] = pottyNotes
            record[VisitFields.pottyRecordedBy] = pottyRecordedBy
            record[VisitFields.pottyIds] = pottyIds
        }
        
        // Set medication records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.medicationRecords.isEmpty {
            let medicationRecordTimestamps = visit.medicationRecords.map { $0.timestamp }
            let medicationRecordNotes = visit.medicationRecords.map { $0.notes ?? "" }
            let medicationRecordRecordedBy = visit.medicationRecords.map { $0.recordedBy ?? "" }
            let medicationRecordIds = visit.medicationRecords.map { $0.id.uuidString }
            
            record[VisitFields.medicationRecordTimestamps] = medicationRecordTimestamps
            record[VisitFields.medicationRecordNotes] = medicationRecordNotes
            record[VisitFields.medicationRecordRecordedBy] = medicationRecordRecordedBy
            record[VisitFields.medicationRecordIds] = medicationRecordIds
        }
        
        // Set medications as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.medications.isEmpty {
            let medicationNames = visit.medications.map { $0.name }
            let medicationTypes = visit.medications.map { $0.type.rawValue }
            let medicationNotes = visit.medications.map { $0.notes ?? "" }
            let medicationIds = visit.medications.map { $0.id.uuidString }
            
            record[VisitFields.medicationNames] = medicationNames
            record[VisitFields.medicationTypes] = medicationTypes
            record[VisitFields.medicationNotes] = medicationNotes
            record[VisitFields.medicationIds] = medicationIds
        }
        
        // Set scheduled medications as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.scheduledMedications.isEmpty {
            let scheduledMedicationDates = visit.scheduledMedications.map { $0.scheduledDate }
            let scheduledMedicationStatuses = visit.scheduledMedications.map { $0.status.rawValue }
            let scheduledMedicationNotes = visit.scheduledMedications.map { $0.notes ?? "" }
            let scheduledMedicationIds = visit.scheduledMedications.map { $0.medicationId.uuidString }
            let scheduledMedicationNotificationTimes = visit.scheduledMedications.map { $0.notificationTime }
            
            record[VisitFields.scheduledMedicationDates] = scheduledMedicationDates
            record[VisitFields.scheduledMedicationStatuses] = scheduledMedicationStatuses
            record[VisitFields.scheduledMedicationNotes] = scheduledMedicationNotes
            record[VisitFields.scheduledMedicationIds] = scheduledMedicationIds
            record[VisitFields.scheduledMedicationNotificationTimes] = scheduledMedicationNotificationTimes
        }
        
        try await publicDatabase.save(record)
        #if DEBUG
        print("✅ Created visit for dog: \(visit.dogId)")
        #endif
    }
    
    func updateVisit(_ visit: Visit) async throws {
        #if DEBUG
        print("📝 Updating visit: \(visit.id)")
        #endif
        
        let predicate = NSPredicate(format: "\(VisitFields.id) == %@", visit.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        // Update fields
        record[VisitFields.departureDate] = visit.departureDate
        record[VisitFields.isBoarding] = visit.isBoarding ? 1 : 0
        record[VisitFields.boardingEndDate] = visit.boardingEndDate
        record[VisitFields.isDeleted] = visit.isDeleted ? 1 : 0
        record[VisitFields.deletedAt] = visit.deletedAt
        record[VisitFields.deletedBy] = visit.deletedBy
        record[VisitFields.updatedAt] = Date()
        record[VisitFields.lastModifiedBy] = visit.lastModifiedBy
        
        // Update feeding records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.feedingRecords.isEmpty {
            let feedingTimestamps = visit.feedingRecords.map { $0.timestamp }
            let feedingTypes = visit.feedingRecords.map { $0.type.rawValue }
            let feedingNotes = visit.feedingRecords.map { $0.notes ?? "" }
            let feedingRecordedBy = visit.feedingRecords.map { $0.recordedBy ?? "" }
            let feedingIds = visit.feedingRecords.map { $0.id.uuidString }
            
            record[VisitFields.feedingTimestamps] = feedingTimestamps
            record[VisitFields.feedingTypes] = feedingTypes
            record[VisitFields.feedingNotes] = feedingNotes
            record[VisitFields.feedingRecordedBy] = feedingRecordedBy
            record[VisitFields.feedingIds] = feedingIds
        }
        
        // Update potty records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.pottyRecords.isEmpty {
            let pottyTimestamps = visit.pottyRecords.map { $0.timestamp }
            let pottyTypes = visit.pottyRecords.map { $0.type.rawValue }
            let pottyNotes = visit.pottyRecords.map { $0.notes ?? "" }
            let pottyRecordedBy = visit.pottyRecords.map { $0.recordedBy ?? "" }
            let pottyIds = visit.pottyRecords.map { $0.id.uuidString }
            
            record[VisitFields.pottyTimestamps] = pottyTimestamps
            record[VisitFields.pottyTypes] = pottyTypes
            record[VisitFields.pottyNotes] = pottyNotes
            record[VisitFields.pottyRecordedBy] = pottyRecordedBy
            record[VisitFields.pottyIds] = pottyIds
        }
        
        // Update medication records as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.medicationRecords.isEmpty {
            let medicationRecordTimestamps = visit.medicationRecords.map { $0.timestamp }
            let medicationRecordNotes = visit.medicationRecords.map { $0.notes ?? "" }
            let medicationRecordRecordedBy = visit.medicationRecords.map { $0.recordedBy ?? "" }
            let medicationRecordIds = visit.medicationRecords.map { $0.id.uuidString }
            
            record[VisitFields.medicationRecordTimestamps] = medicationRecordTimestamps
            record[VisitFields.medicationRecordNotes] = medicationRecordNotes
            record[VisitFields.medicationRecordRecordedBy] = medicationRecordRecordedBy
            record[VisitFields.medicationRecordIds] = medicationRecordIds
        }
        
        // Update medications as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.medications.isEmpty {
            let medicationNames = visit.medications.map { $0.name }
            let medicationTypes = visit.medications.map { $0.type.rawValue }
            let medicationNotes = visit.medications.map { $0.notes ?? "" }
            let medicationIds = visit.medications.map { $0.id.uuidString }
            
            record[VisitFields.medicationNames] = medicationNames
            record[VisitFields.medicationTypes] = medicationTypes
            record[VisitFields.medicationNotes] = medicationNotes
            record[VisitFields.medicationIds] = medicationIds
        }
        
        // Update scheduled medications as individual arrays (only if not empty to avoid CloudKit errors)
        if !visit.scheduledMedications.isEmpty {
            let scheduledMedicationDates = visit.scheduledMedications.map { $0.scheduledDate }
            let scheduledMedicationStatuses = visit.scheduledMedications.map { $0.status.rawValue }
            let scheduledMedicationNotes = visit.scheduledMedications.map { $0.notes ?? "" }
            let scheduledMedicationIds = visit.scheduledMedications.map { $0.medicationId.uuidString }
            let scheduledMedicationNotificationTimes = visit.scheduledMedications.map { $0.notificationTime }
            
            record[VisitFields.scheduledMedicationDates] = scheduledMedicationDates
            record[VisitFields.scheduledMedicationStatuses] = scheduledMedicationStatuses
            record[VisitFields.scheduledMedicationNotes] = scheduledMedicationNotes
            record[VisitFields.scheduledMedicationIds] = scheduledMedicationIds
            record[VisitFields.scheduledMedicationNotificationTimes] = scheduledMedicationNotificationTimes
        }
        
        try await publicDatabase.save(record)
        #if DEBUG
        print("✅ Updated visit: \(visit.id)")
        #endif
    }
    
    func fetchVisits(predicate: NSPredicate? = nil) async throws -> [Visit] {
        #if DEBUG
        print("🔍 Fetching visits...")
        print("   Record type being queried: \(RecordTypes.visit)")
        #endif
        
        let finalPredicate = predicate ?? NSPredicate(value: true)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: finalPredicate)
        query.sortDescriptors = [NSSortDescriptor(key: VisitFields.arrivalDate, ascending: false)]
        
        #if DEBUG
        print("   Executing query for record type: \(query.recordType)")
        print("   Query predicate: \(query.predicate)")
        #endif
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            #if DEBUG
            print("   CloudKit query completed successfully")
            print("   CloudKit returned \(records.count) Visit records")
            if records.isEmpty {
                print("   ⚠️ No Visit records found in CloudKit!")
            }
            #endif
            
            var visits: [Visit] = []
        
        for record in records {
            guard let idString = record[VisitFields.id] as? String,
                  let id = UUID(uuidString: idString),
                  let dogIdString = record[VisitFields.dogId] as? String,
                  let dogId = UUID(uuidString: dogIdString),
                  let arrivalDate = record[VisitFields.arrivalDate] as? Date else {
                continue
            }
            
            let departureDate = record[VisitFields.departureDate] as? Date
            let isBoarding = (record[VisitFields.isBoarding] as? Int64 ?? 0) == 1
            let boardingEndDate = record[VisitFields.boardingEndDate] as? Date
            let isDeleted = (record[VisitFields.isDeleted] as? Int64 ?? 0) == 1
            let deletedAt = record[VisitFields.deletedAt] as? Date
            let deletedBy = record[VisitFields.deletedBy] as? String
            let createdAt = record[VisitFields.createdAt] as? Date ?? Date()
            let updatedAt = record[VisitFields.updatedAt] as? Date ?? Date()
            let createdBy = record[VisitFields.createdBy] as? String
            let lastModifiedBy = record[VisitFields.lastModifiedBy] as? String
            
            // Reconstruct feeding records from individual arrays
            var feedingRecords: [FeedingRecord] = []
            if let feedingTimestamps = record[VisitFields.feedingTimestamps] as? [Date],
               let feedingTypes = record[VisitFields.feedingTypes] as? [String],
               let feedingNotes = record[VisitFields.feedingNotes] as? [String],
               let feedingRecordedBy = record[VisitFields.feedingRecordedBy] as? [String],
               let feedingIds = record[VisitFields.feedingIds] as? [String] {
                
                for i in 0..<feedingTimestamps.count {
                    guard i < feedingTypes.count,
                          i < feedingNotes.count,
                          i < feedingRecordedBy.count,
                          i < feedingIds.count,
                          let feedingId = UUID(uuidString: feedingIds[i]),
                          let feedingType = FeedingRecord.FeedingType(rawValue: feedingTypes[i]) else {
                        continue
                    }
                    
                    var feedingRecord = FeedingRecord(
                        timestamp: feedingTimestamps[i],
                        type: feedingType,
                        notes: feedingNotes[i].isEmpty ? nil : feedingNotes[i],
                        recordedBy: feedingRecordedBy[i].isEmpty ? nil : feedingRecordedBy[i]
                    )
                    feedingRecord.id = feedingId
                    feedingRecords.append(feedingRecord)
                }
            }
            
            // Reconstruct potty records from individual arrays
            var pottyRecords: [PottyRecord] = []
            if let pottyTimestamps = record[VisitFields.pottyTimestamps] as? [Date],
               let pottyTypes = record[VisitFields.pottyTypes] as? [String],
               let pottyNotes = record[VisitFields.pottyNotes] as? [String],
               let pottyRecordedBy = record[VisitFields.pottyRecordedBy] as? [String],
               let pottyIds = record[VisitFields.pottyIds] as? [String] {
                
                for i in 0..<pottyTimestamps.count {
                    guard i < pottyTypes.count,
                          i < pottyNotes.count,
                          i < pottyRecordedBy.count,
                          i < pottyIds.count,
                          let pottyId = UUID(uuidString: pottyIds[i]),
                          let pottyType = PottyRecord.PottyType(rawValue: pottyTypes[i]) else {
                        continue
                    }
                    
                    var pottyRecord = PottyRecord(
                        timestamp: pottyTimestamps[i],
                        type: pottyType,
                        notes: pottyNotes[i].isEmpty ? nil : pottyNotes[i],
                        recordedBy: pottyRecordedBy[i].isEmpty ? nil : pottyRecordedBy[i]
                    )
                    pottyRecord.id = pottyId
                    pottyRecords.append(pottyRecord)
                }
            }
            
            // Reconstruct medication records from individual arrays
            var medicationRecords: [MedicationRecord] = []
            if let medicationRecordTimestamps = record[VisitFields.medicationRecordTimestamps] as? [Date],
               let medicationRecordNotes = record[VisitFields.medicationRecordNotes] as? [String],
               let medicationRecordRecordedBy = record[VisitFields.medicationRecordRecordedBy] as? [String],
               let medicationRecordIds = record[VisitFields.medicationRecordIds] as? [String] {
                
                for i in 0..<medicationRecordTimestamps.count {
                    guard i < medicationRecordNotes.count,
                          i < medicationRecordRecordedBy.count,
                          i < medicationRecordIds.count,
                          let medicationRecordId = UUID(uuidString: medicationRecordIds[i]) else {
                        continue
                    }
                    
                    var medicationRecord = MedicationRecord(
                        timestamp: medicationRecordTimestamps[i],
                        notes: medicationRecordNotes[i].isEmpty ? nil : medicationRecordNotes[i],
                        recordedBy: medicationRecordRecordedBy[i].isEmpty ? nil : medicationRecordRecordedBy[i]
                    )
                    medicationRecord.id = medicationRecordId
                    medicationRecords.append(medicationRecord)
                }
            }
            
            // Reconstruct medications from individual arrays
            var medications: [Medication] = []
            if let medicationNames = record[VisitFields.medicationNames] as? [String],
               let medicationTypes = record[VisitFields.medicationTypes] as? [String],
               let medicationNotes = record[VisitFields.medicationNotes] as? [String],
               let medicationIds = record[VisitFields.medicationIds] as? [String] {
                
                for i in 0..<medicationNames.count {
                    guard i < medicationTypes.count,
                          i < medicationNotes.count,
                          i < medicationIds.count,
                          let medicationId = UUID(uuidString: medicationIds[i]),
                          let medicationType = Medication.MedicationType(rawValue: medicationTypes[i]) else {
                        continue
                    }
                    
                    var medication = Medication(
                        name: medicationNames[i],
                        type: medicationType,
                        notes: medicationNotes[i].isEmpty ? nil : medicationNotes[i]
                    )
                    medication.id = medicationId
                    medications.append(medication)
                }
            }
            
            // Reconstruct scheduled medications from individual arrays
            var scheduledMedications: [ScheduledMedication] = []
            if let scheduledMedicationDates = record[VisitFields.scheduledMedicationDates] as? [Date],
               let scheduledMedicationStatuses = record[VisitFields.scheduledMedicationStatuses] as? [String],
               let scheduledMedicationNotes = record[VisitFields.scheduledMedicationNotes] as? [String],
               let scheduledMedicationIds = record[VisitFields.scheduledMedicationIds] as? [String],
               let scheduledMedicationNotificationTimes = record[VisitFields.scheduledMedicationNotificationTimes] as? [Date] {
                
                for i in 0..<scheduledMedicationDates.count {
                    guard i < scheduledMedicationStatuses.count,
                          i < scheduledMedicationNotes.count,
                          i < scheduledMedicationIds.count,
                          i < scheduledMedicationNotificationTimes.count,
                          let medicationId = UUID(uuidString: scheduledMedicationIds[i]),
                          let status = ScheduledMedication.ScheduledMedicationStatus(rawValue: scheduledMedicationStatuses[i]) else {
                        continue
                    }
                    
                    let scheduledMedication = ScheduledMedication(
                        medicationId: medicationId,
                        scheduledDate: scheduledMedicationDates[i],
                        notificationTime: scheduledMedicationNotificationTimes[i],
                        status: status,
                        notes: scheduledMedicationNotes[i].isEmpty ? nil : scheduledMedicationNotes[i]
                    )
                    scheduledMedications.append(scheduledMedication)
                }
            }
            
            let visit = Visit(
                id: id,
                dogId: dogId,
                arrivalDate: arrivalDate,
                departureDate: departureDate,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                lastModifiedBy: lastModifiedBy,
                feedingRecords: feedingRecords,
                medicationRecords: medicationRecords,
                pottyRecords: pottyRecords,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            visits.append(visit)
            }
            
            #if DEBUG
            print("✅ Fetched \(visits.count) visits")
            #endif
            return visits
        } catch {
            #if DEBUG
            print("   ❌ CloudKit query failed: \(error)")
            #endif
            throw error
        }
    }
    
    func fetchVisitsForDog(_ dogId: UUID, includeDeleted: Bool = false) async throws -> [Visit] {
        let predicate: NSPredicate
        if includeDeleted {
            predicate = NSPredicate(format: "\(VisitFields.dogId) == %@", dogId.uuidString)
        } else {
            predicate = NSPredicate(format: "\(VisitFields.dogId) == %@ AND \(VisitFields.isDeleted) != %@", 
                                   dogId.uuidString, NSNumber(value: true))
        }
        return try await fetchVisits(predicate: predicate)
    }
    
    func fetchActiveVisits() async throws -> [Visit] {
        #if DEBUG
        print("🔍 Fetching today's active visits from CloudKit...")
        #endif
        
        // Create proper predicate for currently active visits
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Fetch visits that are:
        // 1. Currently present (no departure date) OR
        // 2. Departed today (for today's records) OR  
        // 3. Arriving today (future bookings)
        // AND not deleted
        let predicate = NSPredicate(format: "((departureDate == nil) OR (departureDate >= %@ AND departureDate < %@) OR (arrivalDate >= %@ AND arrivalDate < %@)) AND isDeleted == %@", 
                                  today as NSDate, tomorrow as NSDate,    // departed today
                                  today as NSDate, tomorrow as NSDate,    // arriving today
                                  NSNumber(value: false))
        
        let activeVisits = try await fetchVisits(predicate: predicate)
        
        #if DEBUG
        print("📊 Active visits from CloudKit: \(activeVisits.count)")
        for visit in activeVisits {
            let status = visit.departureDate == nil ? "PRESENT" : "departed today"
            print("  - Visit: \(visit.dogId) arrived: \(visit.arrivalDate) [\(status)]")
        }
        #endif
        
        return activeVisits
    }
    
    func fetchAllVisits() async throws -> [Visit] {
        // Fetch all visits without any filtering
        // WARNING: This method is not scalable and should be replaced with date-ranged queries
        let predicate = NSPredicate(value: true)
        return try await fetchVisits(predicate: predicate)
    }
    
    // MARK: - Scalable Date-Ranged Queries
    
    func fetchVisitsInDateRange(from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async throws -> [Visit] {
        let predicate: NSPredicate
        if includeDeleted {
            predicate = NSPredicate(format: "\(VisitFields.arrivalDate) >= %@ AND \(VisitFields.arrivalDate) <= %@", 
                                   startDate as NSDate, endDate as NSDate)
        } else {
            predicate = NSPredicate(format: "\(VisitFields.arrivalDate) >= %@ AND \(VisitFields.arrivalDate) <= %@ AND \(VisitFields.isDeleted) != %@", 
                                   startDate as NSDate, endDate as NSDate, NSNumber(value: true))
        }
        return try await fetchVisits(predicate: predicate)
    }
    
    func fetchRecentVisitsForDog(_ dogId: UUID, limit: Int = 10) async throws -> [Visit] {
        let predicate = NSPredicate(format: "\(VisitFields.dogId) == %@ AND \(VisitFields.isDeleted) != %@", 
                                   dogId.uuidString, NSNumber(value: true))
        let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: VisitFields.arrivalDate, ascending: false)]
        
        let result = try await publicDatabase.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: limit)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        // Use the existing parsing logic from fetchVisits
        var visits: [Visit] = []
        
        for record in records {
            guard let idString = record[VisitFields.id] as? String,
                  let id = UUID(uuidString: idString),
                  let dogIdString = record[VisitFields.dogId] as? String,
                  let dogId = UUID(uuidString: dogIdString),
                  let arrivalDate = record[VisitFields.arrivalDate] as? Date else {
                continue
            }
            
            // Parse the visit (simplified version of the parsing logic from fetchVisits)
            let visit = Visit(
                id: id,
                dogId: dogId,
                arrivalDate: arrivalDate,
                departureDate: record[VisitFields.departureDate] as? Date,
                isBoarding: (record[VisitFields.isBoarding] as? Int64 ?? 0) == 1,
                boardingEndDate: record[VisitFields.boardingEndDate] as? Date,
                isDeleted: (record[VisitFields.isDeleted] as? Int64 ?? 0) == 1,
                deletedAt: record[VisitFields.deletedAt] as? Date,
                deletedBy: record[VisitFields.deletedBy] as? String,
                createdAt: record[VisitFields.createdAt] as? Date ?? Date(),
                updatedAt: record[VisitFields.updatedAt] as? Date ?? Date(),
                createdBy: record[VisitFields.createdBy] as? String,
                lastModifiedBy: record[VisitFields.lastModifiedBy] as? String
            )
            
            visits.append(visit)
        }
        
        return visits
    }
    
    func fetchVisitsInLastNDays(_ days: Int, includeDeleted: Bool = false) async throws -> [Visit] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            throw CloudKitError.unknownError("Failed to calculate start date for last \(days) days")
        }
        
        return try await fetchVisitsInDateRange(from: startDate, to: endDate, includeDeleted: includeDeleted)
    }
    
    func fetchVisitsForDate(_ date: Date) async throws -> [Visit] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "\(VisitFields.arrivalDate) >= %@ AND \(VisitFields.arrivalDate) < %@ AND \(VisitFields.isDeleted) != %@", 
                                   startOfDay as NSDate, endOfDay as NSDate, NSNumber(value: true))
        return try await fetchVisits(predicate: predicate)
    }
    
    func deleteVisit(_ visit: Visit) async throws {
        #if DEBUG
        print("🗑️ Deleting visit: \(visit.id)")
        #endif
        
        let predicate = NSPredicate(format: "\(VisitFields.id) == %@", visit.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: record.recordID)
        #if DEBUG
        print("✅ Deleted visit: \(visit.id)")
        #endif
    }
    
    // MARK: - Utility Methods
    
    func getActiveVisit(for dogId: UUID) async throws -> Visit? {
        let visits = try await fetchVisitsForDog(dogId)
        return visits.first { $0.isCurrentlyPresent }
    }
} 