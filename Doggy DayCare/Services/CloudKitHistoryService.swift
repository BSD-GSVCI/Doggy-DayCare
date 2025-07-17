import Foundation
import CloudKit

@MainActor
class CloudKitHistoryService: ObservableObject {
    static let shared = CloudKitHistoryService()
    
    @Published var historyRecords: [DogHistoryRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitService = CloudKitService.shared
    private let publicDatabase = CKContainer.default().publicCloudDatabase
    private var historyCache: [Date: [DogHistoryRecord]] = [:]
    
    private init() {}
    
    // MARK: - History Management
    
    func recordDailySnapshot(dogs: [Dog]) async {
        let today = Calendar.current.startOfDay(for: Date())
        print("[CloudKitHistoryService] Recording snapshot for \(dogs.count) dogs: \(dogs.map { $0.name }) on \(today)")
        
        // Remove any existing records for today
        await removeHistoryForDate(today)
        
        // Create new records for all dogs
        let newRecords = dogs.map { dog in
            DogHistoryRecord(from: dog, date: today)
        }
        
        // Batch save to CloudKit for better performance
        await batchSaveHistoryRecords(newRecords)
        
        // Update local cache
        await loadHistoryRecords()
        print("[CloudKitHistoryService] Finished recording snapshot for \(newRecords.count) dogs on \(today)")
    }
    
    private func batchSaveHistoryRecords(_ records: [DogHistoryRecord]) async {
        let batchSize = 50 // CloudKit batch limit
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            let ckRecords = batch.map { record in
                let historyRecord = CKRecord(recordType: "DogHistoryRecord")
                // Set record fields
                historyRecord["id"] = record.id.uuidString
                historyRecord["date"] = record.date
                historyRecord["dogId"] = record.dogId.uuidString
                historyRecord["dogName"] = record.dogName
                historyRecord["ownerName"] = record.ownerName
                historyRecord["profilePictureData"] = record.profilePictureData
                historyRecord["arrivalDate"] = record.arrivalDate
                historyRecord["departureDate"] = record.departureDate
                historyRecord["isBoarding"] = record.isBoarding
                historyRecord["boardingEndDate"] = record.boardingEndDate
                historyRecord["isCurrentlyPresent"] = record.isCurrentlyPresent
                historyRecord["shouldBeTreatedAsDaycare"] = record.shouldBeTreatedAsDaycare
                historyRecord["medications"] = record.medications
                historyRecord["specialInstructions"] = record.specialInstructions
                historyRecord["allergiesAndFeedingInstructions"] = record.allergiesAndFeedingInstructions
                historyRecord["needsWalking"] = record.needsWalking
                historyRecord["walkingNotes"] = record.walkingNotes
                historyRecord["isDaycareFed"] = record.isDaycareFed
                historyRecord["notes"] = record.notes
                historyRecord["age"] = record.age
                historyRecord["gender"] = record.gender?.rawValue
                historyRecord["vaccinationEndDate"] = record.vaccinationEndDate
                historyRecord["isNeuteredOrSpayed"] = record.isNeuteredOrSpayed
                historyRecord["ownerPhoneNumber"] = record.ownerPhoneNumber
                historyRecord["isArrivalTimeSet"] = record.isArrivalTimeSet
                historyRecord["visitCount"] = record.visitCount
                historyRecord["createdAt"] = record.createdAt
                historyRecord["updatedAt"] = record.updatedAt
                return historyRecord
            }
            do {
                let result = try await publicDatabase.modifyRecords(saving: ckRecords, deleting: [])
                var successCount = 0
                var failureCount = 0
                for (_, saveResult) in result.saveResults {
                    switch saveResult {
                    case .success(_):
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        print("❌ Error saving record in batch: \(error)")
                    }
                }
                print("✅ Batch \(batchIndex + 1)/\(batches.count): Saved \(successCount) records, \(failureCount) failed")
            } catch {
                print("❌ Failed to save batch \(batchIndex + 1): \(error)")
            }
        }
    }
    
    func getHistoryForDate(_ date: Date) async -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Return cached data immediately if available
        if let cachedRecords = historyCache[startOfDay] {
            print("[CloudKitHistoryService] Returning cached data for \(startOfDay): \(cachedRecords.count) records")
            
            // Always query CloudKit in background for fresh data
            Task {
                await refreshHistoryForDate(startOfDay)
            }
            
            return cachedRecords
        }
        
        // No cache available, query CloudKit and cache the result
        print("[CloudKitHistoryService] No cache for \(startOfDay), querying CloudKit...")
        return await refreshHistoryForDate(startOfDay)
    }
    
    private func refreshHistoryForDate(_ date: Date) async -> [DogHistoryRecord] {
        await loadHistoryRecords()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let records = historyRecords.filter { record in
            record.date >= startOfDay && record.date < endOfDay
        }.sorted { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
        
        // Cache the result
        historyCache[startOfDay] = records
        print("[CloudKitHistoryService] Cached \(records.count) records for \(startOfDay)")
        
        return records
    }
    
    func forceRefreshHistoryForDate(_ date: Date) async -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Clear cache for this date
        historyCache.removeValue(forKey: startOfDay)
        print("[CloudKitHistoryService] Cleared cache for \(startOfDay)")
        
        // Query CloudKit and cache the result
        return await refreshHistoryForDate(startOfDay)
    }
    
    func getAvailableDates() async -> [Date] {
        await loadHistoryRecords()
        
        let dates = Set(historyRecords.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = Array(dates).sorted(by: >)
        print("[CloudKitHistoryService] Available dates: \(sortedDates.count) dates - \(sortedDates.prefix(10).map { $0.formatted(date: .abbreviated, time: .omitted) })")
        return sortedDates
    }
    
    func hasHistoryForDate(_ date: Date) async -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return historyRecords.contains { record in
            record.date >= startOfDay && record.date < endOfDay
        }
    }
    
    func getHistoryForDog(_ dogId: UUID) async -> [DogHistoryRecord] {
        await loadHistoryRecords()
        
        return historyRecords
            .filter { $0.dogId == dogId }
            .sorted { $0.date > $1.date }
    }
    
    func getPresentDogsForDate(_ date: Date) async -> [DogHistoryRecord] {
        let records = await getHistoryForDate(date)
        return records.filter { $0.isCurrentlyPresent }
    }
    
    func getBoardingDogsForDate(_ date: Date) async -> [DogHistoryRecord] {
        let records = await getHistoryForDate(date)
        return records.filter { $0.isBoarding }
    }
    
    func getDaycareDogsForDate(_ date: Date) async -> [DogHistoryRecord] {
        let records = await getHistoryForDate(date)
        return records.filter { !$0.isBoarding }
    }
    
    func getDepartedDogsForDate(_ date: Date) async -> [DogHistoryRecord] {
        let records = await getHistoryForDate(date)
        return records.filter { $0.departureDate != nil }
    }
    
    // MARK: - CloudKit Operations
    

    
    private func loadHistoryRecords() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let predicate = NSPredicate(value: true) // Get all history records
            let query = CKQuery(recordType: "DogHistoryRecord", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            // Use cursor-based pagination for better performance with large datasets
            var allRecords: [CKRecord] = []
            var continuationToken: CKQueryOperation.Cursor?
            
            repeat {
                let queryOperation = CKQueryOperation(query: query)
                queryOperation.resultsLimit = 200 // Process in chunks
                
                if let token = continuationToken {
                    queryOperation.cursor = token
                }
                
                let result = try await withCheckedThrowingContinuation { continuation in
                    var records: [CKRecord] = []
                    
                    queryOperation.recordMatchedBlock = { _, result in
                        switch result {
                        case .success(let record):
                            records.append(record)
                        case .failure(let error):
                            print("❌ Error loading record: \(error)")
                        }
                    }
                    
                    queryOperation.queryResultBlock = { result in
                        switch result {
                        case .success(let cursor):
                            continuation.resume(returning: (records, cursor))
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    publicDatabase.add(queryOperation)
                }
                
                allRecords.append(contentsOf: result.0)
                continuationToken = result.1
                
                print("[CloudKitHistoryService] Loaded batch of \(result.0.count) records, total so far: \(allRecords.count)")
                
            } while continuationToken != nil
            
            var loadedRecords: [DogHistoryRecord] = []
            
            for record in allRecords {
                if let historyRecord = DogHistoryRecord(from: record) {
                    loadedRecords.append(historyRecord)
                }
            }
            
            await MainActor.run {
                self.historyRecords = loadedRecords
                self.isLoading = false
                print("[CloudKitHistoryService] Loaded \(loadedRecords.count) history records from CloudKit")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load history: \(error.localizedDescription)"
                self.isLoading = false
                print("[CloudKitHistoryService] Failed to load history records: \(error)")
            }
        }
    }
    
    private func removeHistoryForDate(_ date: Date) async {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        let query = CKQuery(recordType: "DogHistoryRecord", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            for record in records {
                try await publicDatabase.deleteRecord(withID: record.recordID)
            }
            
            print("🗑️ Removed \(records.count) history records for \(date)")
        } catch {
            print("❌ Failed to remove history records: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldRecords(olderThan days: Int = 90) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
        let query = CKQuery(recordType: "DogHistoryRecord", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            for record in records {
                try await publicDatabase.deleteRecord(withID: record.recordID)
            }
            
            print("🧹 Cleaned up \(records.count) old history records")
            
            // Reload local cache
            await loadHistoryRecords()
        } catch {
            print("❌ Failed to cleanup old records: \(error)")
        }
    }
    
    // MARK: - Debug & Export
    
    func debugHistoryData() async {
        await loadHistoryRecords()
        
        print("=== HISTORY DEBUG INFO ===")
        print("Total records loaded: \(historyRecords.count)")
        
        let dates = Set(historyRecords.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = Array(dates).sorted(by: >)
        
        print("Available dates: \(sortedDates.count)")
        for (index, date) in sortedDates.prefix(10).enumerated() {
            let recordsForDate = historyRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            print("  \(index + 1). \(date.formatted(date: .abbreviated, time: .omitted)): \(recordsForDate.count) dogs")
        }
        
        if let mostRecentDate = sortedDates.first {
            let recentRecords = historyRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: mostRecentDate) }
            print("Most recent date (\(mostRecentDate.formatted(date: .abbreviated, time: .omitted))) has \(recentRecords.count) dogs:")
            for record in recentRecords.prefix(5) {
                print("  - \(record.dogName) (Present: \(record.isCurrentlyPresent))")
            }
        }
        print("=========================")
    }
    
    func exportHistoryRecords() async -> String {
        await loadHistoryRecords()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var csv = "Date,Dog Name,Owner Name,Service Type,Status,Arrival Time,Departure Time,Boarding End Date,Medications,Special Instructions,Notes\n"
        
        for record in historyRecords.sorted(by: { $0.date > $1.date }) {
            // Create row data
            let dateString = formatter.string(from: record.date)
            let dogName = record.dogName
            let ownerName = record.ownerName ?? ""
            let serviceType = record.serviceType
            let statusDescription = record.statusDescription
            let arrivalTime = record.formattedArrivalTime
            let departureTime = record.formattedDepartureTime ?? ""
            let boardingEndDate = record.boardingEndDate != nil ? formatter.string(from: record.boardingEndDate!) : ""
            let medications = record.medications ?? ""
            let specialInstructions = record.specialInstructions ?? ""
            let notes = record.notes ?? ""
            
            // Escape quotes and create CSV row
            let escapedDate = dateString.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedDogName = dogName.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedOwnerName = ownerName.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedServiceType = serviceType.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedStatus = statusDescription.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedArrivalTime = arrivalTime.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedDepartureTime = departureTime.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedBoardingEndDate = boardingEndDate.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedMedications = medications.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedSpecialInstructions = specialInstructions.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
            
            let row = "\"\(escapedDate)\",\"\(escapedDogName)\",\"\(escapedOwnerName)\",\"\(escapedServiceType)\",\"\(escapedStatus)\",\"\(escapedArrivalTime)\",\"\(escapedDepartureTime)\",\"\(escapedBoardingEndDate)\",\"\(escapedMedications)\",\"\(escapedSpecialInstructions)\",\"\(escapedNotes)\""
            
            csv += row + "\n"
        }
        
        return csv
    }
}

// MARK: - DogHistoryRecord Extension

extension DogHistoryRecord {
    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let date = record["date"] as? Date,
              let dogIdString = record["dogId"] as? String,
              let dogId = UUID(uuidString: dogIdString),
              let dogName = record["dogName"] as? String,
              let arrivalDate = record["arrivalDate"] as? Date,
              let isBoarding = record["isBoarding"] as? Bool,
              let isCurrentlyPresent = record["isCurrentlyPresent"] as? Bool,
              let shouldBeTreatedAsDaycare = record["shouldBeTreatedAsDaycare"] as? Bool,
              let needsWalking = record["needsWalking"] as? Bool,
              let isDaycareFed = record["isDaycareFed"] as? Bool,
              let isArrivalTimeSet = record["isArrivalTimeSet"] as? Bool,
              let visitCount = record["visitCount"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }
        
        self.id = id
        self.date = date
        self.dogId = dogId
        self.dogName = dogName
        self.ownerName = record["ownerName"] as? String
        self.profilePictureData = record["profilePictureData"] as? Data
        self.arrivalDate = arrivalDate
        self.departureDate = record["departureDate"] as? Date
        self.isBoarding = isBoarding
        self.boardingEndDate = record["boardingEndDate"] as? Date
        self.isCurrentlyPresent = isCurrentlyPresent
        self.shouldBeTreatedAsDaycare = shouldBeTreatedAsDaycare
        self.medications = record["medications"] as? String
        self.specialInstructions = record["specialInstructions"] as? String
        self.allergiesAndFeedingInstructions = record["allergiesAndFeedingInstructions"] as? String
        self.needsWalking = needsWalking
        self.walkingNotes = record["walkingNotes"] as? String
        self.isDaycareFed = isDaycareFed
        self.notes = record["notes"] as? String
        self.age = record["age"] as? Int
        self.gender = DogGender(rawValue: record["gender"] as? String ?? "unknown")
        self.vaccinationEndDate = record["vaccinationEndDate"] as? Date
        self.isNeuteredOrSpayed = record["isNeuteredOrSpayed"] as? Bool
        self.ownerPhoneNumber = record["ownerPhoneNumber"] as? String
        self.isArrivalTimeSet = isArrivalTimeSet
        self.visitCount = visitCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 