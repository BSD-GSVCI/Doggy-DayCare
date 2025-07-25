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
    private var lastSyncTimes: [Date: Date] = [:]
    
    private init() {}
    
    // MARK: - History Management
    
    func recordDailySnapshot(dogs: [Dog]) async {
        let today = Calendar.current.startOfDay(for: Date())
        await recordSnapshot(for: today, dogs: dogs)
    }
    
    // Record a snapshot for an arbitrary date using the provided dogs
    func recordSnapshot(for date: Date, dogs: [Dog]) async {
        let snapshotDate = Calendar.current.startOfDay(for: date)
        print("[CloudKitHistoryService] Recording snapshot for \(dogs.count) dogs: \(dogs.map { $0.name }) on \(snapshotDate)")
        // 1. Delete all existing records for the date
        await removeHistoryForDate(snapshotDate)
        // 2. Create new records for all dogs (force date = snapshotDate)
        let newRecords = dogs.map { dog in
            DogHistoryRecord(from: dog, date: snapshotDate)
        }
        print("[CloudKitHistoryService] Will write records:")
        for rec in newRecords {
            print("  - id: \(rec.id), dogId: \(rec.dogId), date: \(rec.date)")
        }
        // 3. Batch save all new records
        await batchSaveHistoryRecords(newRecords)
        // 4. Update cache and UI for the date to match the new snapshot
        historyCache[snapshotDate] = newRecords
        let allOtherRecords = historyRecords.filter { Calendar.current.startOfDay(for: $0.date) != snapshotDate }
        self.historyRecords = (allOtherRecords + newRecords).sorted { $0.date > $1.date }
        // 5. Optionally, reload all history from CloudKit if you want to guarantee full sync
        await loadHistoryRecords()
        print("[CloudKitHistoryService] After load, records for \(snapshotDate):")
        let loaded = historyRecords.filter { $0.date == snapshotDate }
        for rec in loaded {
            print("  - id: \(rec.id), dogId: \(rec.dogId), date: \(rec.date)")
        }
        // 6. Update last sync time for the date
        lastSyncTimes[snapshotDate] = Date()
        print("[CloudKitHistoryService] Finished recording snapshot for \(newRecords.count) dogs on \(snapshotDate)")
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
                // Store each vaccine end date as an explicit field
                historyRecord["bordetellaEndDate"] = record.vaccinations.first(where: { $0.name == "Bordetella" })?.endDate
                historyRecord["dhppEndDate"] = record.vaccinations.first(where: { $0.name == "DHPP" })?.endDate
                historyRecord["rabiesEndDate"] = record.vaccinations.first(where: { $0.name == "Rabies" })?.endDate
                historyRecord["civEndDate"] = record.vaccinations.first(where: { $0.name == "CIV" })?.endDate
                historyRecord["leptospirosisEndDate"] = record.vaccinations.first(where: { $0.name == "Leptospirosis" })?.endDate
                historyRecord["isNeuteredOrSpayed"] = record.isNeuteredOrSpayed
                historyRecord["ownerPhoneNumber"] = record.ownerPhoneNumber
                historyRecord["isArrivalTimeSet"] = record.isArrivalTimeSet
                historyRecord["visitCount"] = record.visitCount
                historyRecord["createdAt"] = record.createdAt
                historyRecord["updatedAt"] = record.updatedAt
                historyRecord["isDeleted"] = record.isDeleted ? 1 : 0
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
    
    private func batchUpdateHistoryRecords(_ records: [DogHistoryRecord]) async {
        let batchSize = 50 // CloudKit batch limit
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            // For updates, we need to fetch existing records first, then modify them
            let recordIDs = batch.map { CKRecord.ID(recordName: $0.id.uuidString) }
            
            do {
                // Fetch existing records
                let fetchResult = try await publicDatabase.records(for: recordIDs)
                var recordsToUpdate: [CKRecord] = []
                
                for (index, record) in batch.enumerated() {
                    if let result = fetchResult[recordIDs[index]],
                       let existingRecord = try? result.get() {
                        // Update the existing record with new data
                        existingRecord["date"] = record.date
                        existingRecord["dogId"] = record.dogId.uuidString
                        existingRecord["dogName"] = record.dogName
                        existingRecord["ownerName"] = record.ownerName
                        existingRecord["profilePictureData"] = record.profilePictureData
                        existingRecord["arrivalDate"] = record.arrivalDate
                        existingRecord["departureDate"] = record.departureDate
                        existingRecord["isBoarding"] = record.isBoarding
                        existingRecord["boardingEndDate"] = record.boardingEndDate
                        existingRecord["isCurrentlyPresent"] = record.isCurrentlyPresent
                        existingRecord["shouldBeTreatedAsDaycare"] = record.shouldBeTreatedAsDaycare
                        existingRecord["medications"] = record.medications
                        existingRecord["specialInstructions"] = record.specialInstructions
                        existingRecord["allergiesAndFeedingInstructions"] = record.allergiesAndFeedingInstructions
                        existingRecord["needsWalking"] = record.needsWalking
                        existingRecord["walkingNotes"] = record.walkingNotes
                        existingRecord["isDaycareFed"] = record.isDaycareFed
                        existingRecord["notes"] = record.notes
                        existingRecord["age"] = record.age
                        existingRecord["gender"] = record.gender?.rawValue
                        // Store each vaccine end date as an explicit field
                        existingRecord["bordetellaEndDate"] = record.vaccinations.first(where: { $0.name == "Bordetella" })?.endDate
                        existingRecord["dhppEndDate"] = record.vaccinations.first(where: { $0.name == "DHPP" })?.endDate
                        existingRecord["rabiesEndDate"] = record.vaccinations.first(where: { $0.name == "Rabies" })?.endDate
                        existingRecord["civEndDate"] = record.vaccinations.first(where: { $0.name == "CIV" })?.endDate
                        existingRecord["leptospirosisEndDate"] = record.vaccinations.first(where: { $0.name == "Leptospirosis" })?.endDate
                        existingRecord["isNeuteredOrSpayed"] = record.isNeuteredOrSpayed
                        existingRecord["ownerPhoneNumber"] = record.ownerPhoneNumber
                        existingRecord["isArrivalTimeSet"] = record.isArrivalTimeSet
                        existingRecord["visitCount"] = record.visitCount
                        existingRecord["createdAt"] = record.createdAt
                        existingRecord["updatedAt"] = record.updatedAt
                        existingRecord["isDeleted"] = record.isDeleted ? 1 : 0
                        recordsToUpdate.append(existingRecord)
                    }
                }
                
                if !recordsToUpdate.isEmpty {
                    let result = try await publicDatabase.modifyRecords(saving: recordsToUpdate, deleting: [])
                    var successCount = 0
                    var failureCount = 0
                    for (_, saveResult) in result.saveResults {
                        switch saveResult {
                        case .success(_):
                            successCount += 1
                        case .failure(let error):
                            failureCount += 1
                            print("❌ Error updating record in batch: \(error)")
                        }
                    }
                    print("✅ Batch \(batchIndex + 1)/\(batches.count): Updated \(successCount) records, \(failureCount) failed")
                } else {
                    print("⚠️ No records to update in batch \(batchIndex + 1)")
                }
            } catch {
                print("❌ Failed to update batch \(batchIndex + 1): \(error)")
            }
        }
    }
    
    private func batchDeleteHistoryRecords(_ records: [DogHistoryRecord]) async {
        let batchSize = 50 // CloudKit batch limit
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            let recordIDs = batch.map { CKRecord.ID(recordName: $0.id.uuidString) }
            
            do {
                let result = try await publicDatabase.modifyRecords(saving: [], deleting: recordIDs)
                var successCount = 0
                var failureCount = 0
                for (_, deleteResult) in result.deleteResults {
                    switch deleteResult {
                    case .success(_):
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        print("❌ Error deleting record in batch: \(error)")
                    }
                }
                print("✅ Batch \(batchIndex + 1)/\(batches.count): Deleted \(successCount) records, \(failureCount) failed")
            } catch {
                print("❌ Failed to delete batch \(batchIndex + 1): \(error)")
            }
        }
    }
    
    func getHistoryForDate(_ date: Date) async -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Return cached data immediately if available
        if let cachedRecords = historyCache[startOfDay] {
            print("[CloudKitHistoryService] Returning cached data for \(startOfDay): \(cachedRecords.count) records")
            
            // Background incremental update
            Task {
                await incrementalUpdateForDate(startOfDay)
            }
            
            return cachedRecords
        }
        
        // No cache available, query CloudKit and cache the result
        print("[CloudKitHistoryService] No cache for \(startOfDay), querying CloudKit...")
        return await updateCacheForDate(startOfDay)
    }
    
    func updateCacheForDate(_ date: Date) async -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        print("[CloudKitHistoryService] updateCacheForDate called for \(startOfDay)")
        
        // Load fresh data from CloudKit
        await loadHistoryRecords()
        
        let records = historyRecords.filter { record in
            record.date >= startOfDay && record.date < Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        }.sorted { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
        
        // Update cache with fresh data
        historyCache[startOfDay] = records
        print("[CloudKitHistoryService] Updated cache for \(startOfDay): \(records.count) records, total cache entries: \(historyCache.count)")
        
        return records
    }
    
    private func incrementalUpdateForDate(_ date: Date) async {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let lastSync = lastSyncTimes[startOfDay] ?? Date.distantPast
        
        print("[CloudKitHistoryService] Incremental update for \(startOfDay), last sync: \(lastSync)")
        
        // Query only records modified since last sync
        let predicate = NSPredicate(format: "date >= %@ AND date < %@ AND updatedAt > %@", 
                                   startOfDay as NSDate, 
                                   Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate,
                                   lastSync as NSDate)
        
        let query = CKQuery(recordType: "DogHistoryRecord", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let changedRecords = result.matchResults.compactMap { try? $0.1.get() }
            
            if !changedRecords.isEmpty {
                print("[CloudKitHistoryService] Found \(changedRecords.count) changed records for \(startOfDay)")
                
                // Update cache with only changed records
                await updateCacheWithChanges(for: startOfDay, changedRecords: changedRecords)
                
                // Also update historyRecords for the affected date
                let allOtherRecords = historyRecords.filter { Calendar.current.startOfDay(for: $0.date) != startOfDay }
                let updatedRecords = allOtherRecords + (historyCache[startOfDay] ?? [])
                self.historyRecords = updatedRecords.sorted { $0.date > $1.date }
                
                // Update last sync time
                lastSyncTimes[startOfDay] = Date()
            } else {
                print("[CloudKitHistoryService] No changes found for \(startOfDay)")
            }
        } catch {
            print("[CloudKitHistoryService] Incremental update failed: \(error)")
        }
    }
    
    private func updateCacheWithChanges(for date: Date, changedRecords: [CKRecord]) async {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Convert CKRecords to DogHistoryRecords
        let newHistoryRecords = changedRecords.compactMap { DogHistoryRecord(from: $0) }
        
        // Get current cached records
        var currentRecords = historyCache[startOfDay] ?? []
        
        // Update or add changed records
        for newRecord in newHistoryRecords {
            if let index = currentRecords.firstIndex(where: { $0.id == newRecord.id }) {
                // Update existing record
                currentRecords[index] = newRecord
                print("[CloudKitHistoryService] Updated record: \(newRecord.dogName)")
            } else {
                // Add new record
                currentRecords.append(newRecord)
                print("[CloudKitHistoryService] Added new record: \(newRecord.dogName)")
            }
        }
        
        // Sort and update cache
        currentRecords.sort { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
        historyCache[startOfDay] = currentRecords
        
        // After updating historyCache[startOfDay], update historyRecords for the affected date
        let allOtherRecords = historyRecords.filter { Calendar.current.startOfDay(for: $0.date) != startOfDay }
        let updatedRecords = allOtherRecords + currentRecords
        self.historyRecords = updatedRecords.sorted { $0.date > $1.date }
        
        print("[CloudKitHistoryService] Cache updated for \(startOfDay): \(currentRecords.count) records")
    }
    
    private func silentUpdateCacheForDate(_ date: Date) async {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        print("[CloudKitHistoryService] Silent background update for \(startOfDay)")
        
        // Load fresh data from CloudKit without affecting loading state
        await loadHistoryRecordsSilently()
        
        let records = historyRecords.filter { record in
            record.date >= startOfDay && record.date < Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        }.sorted { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
        
        // Update cache with fresh data
        historyCache[startOfDay] = records
        print("[CloudKitHistoryService] Silent cache update for \(startOfDay): \(records.count) records")
    }
    
    private func loadHistoryRecordsSilently() async {
        // Same as loadHistoryRecords but doesn't set isLoading
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
                
                print("[CloudKitHistoryService] Silent load: \(result.0.count) records, total so far: \(allRecords.count)")
                
            } while continuationToken != nil
            
            var loadedRecords: [DogHistoryRecord] = []
            
            for record in allRecords {
                if let historyRecord = DogHistoryRecord(from: record) {
                    loadedRecords.append(historyRecord)
                }
            }
            
            await MainActor.run {
                // Simply update the records without clearing cache
                // The cache is organized by date, so changes to one date shouldn't affect others
                self.historyRecords = loadedRecords
                print("[CloudKitHistoryService] Silent load completed: \(loadedRecords.count) records")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load history: \(error.localizedDescription)"
                print("[CloudKitHistoryService] Silent load failed: \(error)")
            }
        }
    }
    
    func forceRefreshHistoryForDate(_ date: Date) async -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Force update cache for this date
        print("[CloudKitHistoryService] Force refreshing cache for \(startOfDay)")
        
        // Query CloudKit and update cache
        return await updateCacheForDate(startOfDay)
    }
    
    func getAvailableDates() async -> [Date] {
        // Use existing data if available, otherwise load from CloudKit
        if historyRecords.isEmpty {
            await loadHistoryRecords()
        }
        
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
    
    // MARK: - Cache Management
    
    func preloadHistoryData() async {
        print("[CloudKitHistoryService] Preloading history data...")
        
        // Load fresh data from CloudKit
        await loadHistoryRecords()
        
        // Pre-cache data for available dates
        let dates = Set(historyRecords.map { Calendar.current.startOfDay(for: $0.date) })
        for date in dates {
            let startOfDay = date
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let records = historyRecords.filter { record in
                record.date >= startOfDay && record.date < endOfDay
            }.sorted { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
            
            historyCache[startOfDay] = records
            print("[CloudKitHistoryService] Pre-cached \(records.count) records for \(startOfDay)")
        }
        
        print("[CloudKitHistoryService] Preloaded data for \(dates.count) dates")
    }
    
    func clearCache() {
        historyCache.removeAll()
        print("[CloudKitHistoryService] Cache manually cleared")
    }
    
    func clearCacheForDate(_ date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        historyCache.removeValue(forKey: startOfDay)
        print("[CloudKitHistoryService] Cache cleared for \(startOfDay)")
    }
    
    func debugCacheState() {
        print("[CloudKitHistoryService] Cache state: \(historyCache.count) entries")
        for (date, records) in historyCache {
            print("  - \(date): \(records.count) records")
        }
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
                // Simply update the records without clearing cache
                // The cache is organized by date, so changes to one date shouldn't affect others
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
        // Build vaccinations array from explicit fields
        self.vaccinations = [
            VaccinationItem(name: "Bordetella", endDate: record["bordetellaEndDate"] as? Date),
            VaccinationItem(name: "DHPP", endDate: record["dhppEndDate"] as? Date),
            VaccinationItem(name: "Rabies", endDate: record["rabiesEndDate"] as? Date),
            VaccinationItem(name: "CIV", endDate: record["civEndDate"] as? Date),
            VaccinationItem(name: "Leptospirosis", endDate: record["leptospirosisEndDate"] as? Date)
        ]
        self.isNeuteredOrSpayed = record["isNeuteredOrSpayed"] as? Bool
        self.ownerPhoneNumber = record["ownerPhoneNumber"] as? String
        self.isArrivalTimeSet = isArrivalTimeSet
        self.visitCount = visitCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = (record["isDeleted"] as? Int64 ?? 0) == 1
    }
} 