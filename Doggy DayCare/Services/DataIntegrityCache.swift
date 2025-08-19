import Foundation
import CloudKit

/// Enterprise-grade cache system that ensures absolute data integrity between UI, Cache, and CloudKit
/// Uses Swift's actor model for guaranteed thread safety in business-critical operations
actor DataIntegrityCache {
    static let shared = DataIntegrityCache()
    
    // MARK: - Cache Storage
    
    /// Single source of truth for all cached data
    private struct CacheState {
        var persistentDogs: [UUID: PersistentDog] = [:]
        var visits: [UUID: Visit] = [:]
        var version: Int = 0
        var lastCloudKitSync: Date = Date.distantPast
        var changeTokens: [String: CKServerChangeToken] = [:]
    }
    
    /// Actor-isolated cache state (thread safety guaranteed by Swift)
    private var state = CacheState()
    
    /// Pending operations that haven't been confirmed by CloudKit
    private var pendingOperations: [UUID: PendingOperation] = [:]
    
    private struct PendingOperation {
        let id: UUID = UUID()
        let type: OperationType
        let timestamp: Date = Date()
        let originalState: CacheState
        
        enum OperationType {
            case addDog(PersistentDog, Visit)
            case updateDog(PersistentDog)
            case updateVisit(Visit)
            case deleteDog(UUID)
            case deleteVisit(UUID)
            case checkoutDog(UUID, Date)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        print("🔒 DataIntegrityCache initialized with enterprise-grade data protection")
        #endif
    }
    
    // MARK: - Atomic Operations
    
    /// Atomically get all dogs with their visits (main page display)
    func getCurrentDogsWithVisits() -> [DogWithVisit] {
        let activeVisits = state.visits.values.filter { $0.isCurrentlyPresent }
        return state.persistentDogs.values.compactMap { dog in
            if let visit = activeVisits.first(where: { $0.dogId == dog.id }) {
                return DogWithVisit(persistentDog: dog, currentVisit: visit)
            }
            return nil
        }
    }
    
    /// Atomically get all persistent dogs (for database view)
    func getAllPersistentDogs() -> [PersistentDog] {
        Array(state.persistentDogs.values)
    }
    
    /// Atomically get all visits
    func getAllVisits() -> [Visit] {
        Array(state.visits.values)
    }
    
    // MARK: - Transactional Updates
    
    /// Add a new dog with visit - atomic operation with rollback capability
    func addDogWithVisit(
        persistentDog: PersistentDog,
        visit: Visit,
        cloudKitConfirmation: @escaping () async throws -> Void
    ) async throws {
        
        // 1. Check for conflicts before proceeding
        if let existingDog = state.persistentDogs[persistentDog.id] {
            // Dog already exists - this could be a duplicate or conflict
            let existingDogWithVisit = DogWithVisit(persistentDog: existingDog, currentVisit: nil)
            
            if existingDogWithVisit.isCurrentlyPresent {
                throw DataIntegrityError.conflictDetected("Dog \(persistentDog.name) is already checked in")
            }
        }
        
        // 2. Capture original state for rollback
        let originalState = state
        
        // 3. Create pending operation
        let operation = PendingOperation(
            type: .addDog(persistentDog, visit),
            originalState: originalState
        )
        pendingOperations[operation.id] = operation
        
        // 4. Update cache atomically
        // Actor isolation ensures atomic updates
        state.persistentDogs[persistentDog.id] = persistentDog
        state.visits[visit.id] = visit
        state.version += 1
        
        // 5. Execute CloudKit operation with conflict detection
        do {
            try await cloudKitConfirmation()
            
            // 6. Mark operation as successful
            pendingOperations.removeValue(forKey: operation.id)
            
            #if DEBUG
            print("✅ DataIntegrityCache: Successfully added dog \(persistentDog.name) with full data integrity")
            #endif
            
        } catch let error as CKError where error.code == .serverRecordChanged {
            // 7. Handle CloudKit conflicts
            #if DEBUG
            print("⚠️ CloudKit conflict detected for \(persistentDog.name)")
            #endif
            
            // Rollback and re-sync to get latest state
            await rollback(operation: operation)
            throw DataIntegrityError.conflictDetected("Another user modified this dog's data")
            
        } catch {
            // 8. ROLLBACK on other CloudKit failures
            await rollback(operation: operation)
            
            #if DEBUG
            print("❌ DataIntegrityCache: Rolled back dog addition due to CloudKit error: \(error)")
            #endif
            
            throw DataIntegrityError.cloudKitSyncFailed(error)
        }
    }
    
    /// Update existing dog - atomic with rollback
    func updateDog(
        _ dog: PersistentDog,
        cloudKitConfirmation: @escaping () async throws -> Void
    ) async throws {
        
        let originalState = state
        let operation = PendingOperation(type: .updateDog(dog), originalState: originalState)
        pendingOperations[operation.id] = operation
        
        // Update cache (actor isolation ensures atomicity)
        state.persistentDogs[dog.id] = dog
        state.version += 1
        
        do {
            try await cloudKitConfirmation()
            pendingOperations.removeValue(forKey: operation.id)
        } catch {
            await rollback(operation: operation)
            throw DataIntegrityError.cloudKitSyncFailed(error)
        }
    }
    
    /// Update visit - atomic with rollback
    func updateVisit(
        _ visit: Visit,
        cloudKitConfirmation: @escaping () async throws -> Void
    ) async throws {
        
        let originalState = state
        let operation = PendingOperation(type: .updateVisit(visit), originalState: originalState)
        pendingOperations[operation.id] = operation
        
        // Update cache (actor isolation ensures atomicity)
        state.visits[visit.id] = visit
        state.version += 1
        
        do {
            try await cloudKitConfirmation()
            pendingOperations.removeValue(forKey: operation.id)
        } catch {
            await rollback(operation: operation)
            throw DataIntegrityError.cloudKitSyncFailed(error)
        }
    }
    
    /// Delete visit - atomic with rollback
    func deleteVisit(
        _ visit: Visit,
        cloudKitConfirmation: @escaping () async throws -> Void
    ) async throws {
        
        let originalState = state
        let operation = PendingOperation(type: .deleteVisit(visit.id), originalState: originalState)
        pendingOperations[operation.id] = operation
        
        // Remove from cache (actor isolation ensures atomicity)
        state.visits.removeValue(forKey: visit.id)
        state.version += 1
        
        do {
            try await cloudKitConfirmation()
            pendingOperations.removeValue(forKey: operation.id)
            
            #if DEBUG
            print("✅ DataIntegrityCache: Successfully deleted visit \(visit.id)")
            #endif
            
        } catch {
            await rollback(operation: operation)
            
            #if DEBUG
            print("❌ DataIntegrityCache: Rolled back visit deletion due to CloudKit error: \(error)")
            #endif
            
            throw DataIntegrityError.cloudKitSyncFailed(error)
        }
    }
    
    // MARK: - Rollback Mechanism
    
    private func rollback(operation: PendingOperation) async {
        // Restore original state (actor isolation ensures atomicity)
        state = operation.originalState
        
        #if DEBUG
        print("🔄 DataIntegrityCache: Rolled back to version \(operation.originalState.version)")
        #endif
        
        // Remove from pending
        pendingOperations.removeValue(forKey: operation.id)
    }
    
    // MARK: - Data Integrity Validation
    
    /// Validates cache consistency with CloudKit
    func validateIntegrity() async throws -> IntegrityReport {
        let cacheState = state
        
        var report = IntegrityReport()
        
        // 1. Check for stale pending operations (potential CloudKit sync failures)
        let staleOperations = pendingOperations.values.filter { 
            Date().timeIntervalSince($0.timestamp) > 30 
        }
        
        if !staleOperations.isEmpty {
            report.warnings.append("Found \(staleOperations.count) stale pending operations")
            for op in staleOperations {
                switch op.type {
                case .addDog(let dog, _):
                    report.warnings.append("  - Pending add: \(dog.name)")
                case .updateDog(let dog):
                    report.warnings.append("  - Pending update: \(dog.name)")
                case .deleteVisit(let visitId):
                    report.warnings.append("  - Pending delete visit: \(visitId)")
                default:
                    break
                }
            }
        }
        
        // 2. Validate all relationships are intact
        for visit in cacheState.visits.values {
            if cacheState.persistentDogs[visit.dogId] == nil {
                report.errors.append("❌ Orphaned visit \(visit.id) - no matching dog")
            }
        }
        
        // 3. Check for duplicate visits (same dog, overlapping times)
        let activeVisits = cacheState.visits.values.filter { $0.isCurrentlyPresent }
        var dogVisitMap: [UUID: [Visit]] = [:]
        
        for visit in activeVisits {
            dogVisitMap[visit.dogId, default: []].append(visit)
        }
        
        for (dogId, visits) in dogVisitMap where visits.count > 1 {
            if let dogName = cacheState.persistentDogs[dogId]?.name {
                report.errors.append("❌ Dog '\(dogName)' has \(visits.count) active visits simultaneously")
            }
        }
        
        // 4. Validate visit dates
        for visit in cacheState.visits.values {
            if let departure = visit.departureDate, departure < visit.arrivalDate {
                if let dogName = cacheState.persistentDogs[visit.dogId]?.name {
                    report.errors.append("❌ Dog '\(dogName)' has departure before arrival")
                }
            }
        }
        
        // 5. Check cache freshness
        let timeSinceSync = Date().timeIntervalSince(cacheState.lastCloudKitSync)
        if timeSinceSync > 300 { // 5 minutes
            report.warnings.append("⚠️ Cache hasn't synced with CloudKit for \(Int(timeSinceSync/60)) minutes")
        }
        
        report.isValid = report.errors.isEmpty
        report.cacheVersion = cacheState.version
        report.lastSync = cacheState.lastCloudKitSync
        
        return report
    }
    
    /// Performs deep validation against CloudKit data
    func validateAgainstCloudKit(
        fetchPersistentDogs: @escaping () async throws -> [PersistentDog],
        fetchVisits: @escaping () async throws -> [Visit]
    ) async throws -> IntegrityReport {
        
        var report = IntegrityReport()
        
        // Fetch fresh data from CloudKit
        let cloudKitDogs = try await fetchPersistentDogs()
        let cloudKitVisits = try await fetchVisits()
        
        // Get current cache state
        let cacheState = state
        
        // Compare counts
        if cloudKitDogs.count != cacheState.persistentDogs.count {
            report.warnings.append("Dog count mismatch: Cache(\(cacheState.persistentDogs.count)) vs CloudKit(\(cloudKitDogs.count))")
        }
        
        if cloudKitVisits.count != cacheState.visits.count {
            report.warnings.append("Visit count mismatch: Cache(\(cacheState.visits.count)) vs CloudKit(\(cloudKitVisits.count))")
        }
        
        // Check for missing dogs in cache
        for cloudDog in cloudKitDogs {
            if cacheState.persistentDogs[cloudDog.id] == nil {
                report.errors.append("❌ Dog '\(cloudDog.name)' exists in CloudKit but not in cache")
            }
        }
        
        // Check for extra dogs in cache
        for (dogId, cacheDog) in cacheState.persistentDogs {
            if !cloudKitDogs.contains(where: { $0.id == dogId }) {
                // Check if it's a pending operation
                let isPending = pendingOperations.values.contains { op in
                    if case .addDog(let dog, _) = op.type {
                        return dog.id == dogId
                    }
                    return false
                }
                
                if !isPending {
                    report.errors.append("❌ Dog '\(cacheDog.name)' exists in cache but not in CloudKit")
                }
            }
        }
        
        report.isValid = report.errors.isEmpty
        report.cacheVersion = cacheState.version
        report.lastSync = cacheState.lastCloudKitSync
        
        return report
    }
    
    // MARK: - Multi-User Sync
    
    /// Sync with CloudKit to get changes from other users with conflict resolution
    func syncWithCloudKit(
        fetchPersistentDogs: @escaping () async throws -> [PersistentDog],
        fetchVisits: @escaping () async throws -> [Visit]
    ) async throws {
        
        #if DEBUG
        print("🔄 DataIntegrityCache: Starting CloudKit sync for multi-user consistency")
        #endif
        
        // Capture current state for conflict resolution
        let currentState = state
        
        // Fetch fresh data from CloudKit
        let cloudKitDogs = try await fetchPersistentDogs()
        let cloudKitVisits = try await fetchVisits()
        
        // Detect and resolve conflicts
        var resolvedDogs: [UUID: PersistentDog] = [:]
        var resolvedVisits: [UUID: Visit] = [:]
        var conflictResolutions: [ConflictResolution] = []
        
        // Process each CloudKit dog and check for conflicts
        for cloudDog in cloudKitDogs {
            if let localDog = currentState.persistentDogs[cloudDog.id] {
                // Dog exists in both - check for conflicts
                let localVisit = currentState.visits.values.first { $0.dogId == cloudDog.id }
                let cloudVisit = cloudKitVisits.first { $0.dogId == cloudDog.id }
                
                let localDogWithVisit = DogWithVisit(persistentDog: localDog, currentVisit: localVisit)
                let cloudDogWithVisit = DogWithVisit(persistentDog: cloudDog, currentVisit: cloudVisit)
                
                // Skip conflict resolution if data is identical OR if there's a pending operation
                let hasPendingOperation = pendingOperations.values.contains { operation in
                    switch operation.type {
                    case .addDog(let pendingDog, _), .updateDog(let pendingDog):
                        return pendingDog.id == cloudDog.id
                    case .deleteDog(let pendingDogId):
                        return pendingDogId == cloudDog.id
                    case .updateVisit(let pendingVisit):
                        return pendingVisit.dogId == cloudDog.id
                    case .deleteVisit(let pendingVisitId):
                        // Check if this visit belongs to this dog
                        return currentState.visits[pendingVisitId]?.dogId == cloudDog.id
                    case .checkoutDog(let pendingDogId, _):
                        return pendingDogId == cloudDog.id
                    }
                }
                
                if localDogWithVisit != cloudDogWithVisit && !hasPendingOperation {
                    let resolution = await ConflictResolver.shared.resolveConflict(
                        local: localDogWithVisit,
                        remote: cloudDogWithVisit,
                        localUser: nil, // Would need current user context
                        remoteUser: nil // Would need remote user context
                    )
                    
                    // Apply field updates and record merges from conflict resolution
                    resolvedDogs[cloudDog.id] = cloudDog
                    if let cloudVisit = cloudVisit {
                        resolvedVisits[cloudVisit.id] = cloudVisit
                    }
                    
                    // Apply the conflict resolution updates
                    applyConflictResolution(
                        resolution: resolution,
                        resolvedDogs: &resolvedDogs,
                        resolvedVisits: &resolvedVisits
                    )
                    
                    conflictResolutions.append(resolution)
                    
                    #if DEBUG
                    if !resolution.conflicts.isEmpty {
                        print("⚠️ Resolved \(resolution.conflicts.count) conflicts for \(cloudDog.name)")
                        print("   - Applied \(resolution.fieldUpdates.count) field updates")
                        print("   - Applied \(resolution.recordMerges.count) record merges")
                    }
                    #endif
                } else if hasPendingOperation {
                    // Skip conflict resolution - pending operation in progress
                    #if DEBUG
                    print("⏸️ Skipping conflict resolution for \(cloudDog.name) - pending operation in progress")
                    #endif
                    // Don't add to resolvedDogs - will be handled in pending operations section
                } else {
                    // No conflicts - use CloudKit version
                    resolvedDogs[cloudDog.id] = cloudDog
                }
            } else {
                // New dog from CloudKit
                resolvedDogs[cloudDog.id] = cloudDog
            }
        }
        
        // Add visits that don't belong to dogs (shouldn't happen, but defensive)
        for cloudVisit in cloudKitVisits {
            if resolvedDogs[cloudVisit.dogId] != nil && resolvedVisits[cloudVisit.id] == nil {
                resolvedVisits[cloudVisit.id] = cloudVisit
            }
        }
        
        // Update cache atomically with resolved data (actor isolation ensures thread safety)
        // Preserve pending operations by re-applying them
        for operation in pendingOperations.values {
            switch operation.type {
            case .addDog(let dog, let visit):
                resolvedDogs[dog.id] = dog
                resolvedVisits[visit.id] = visit
            case .updateDog(let dog):
                // Only apply if we don't have a more recent version
                if resolvedDogs[dog.id] == nil || 
                   resolvedDogs[dog.id]?.updatedAt ?? Date.distantPast < dog.updatedAt {
                    resolvedDogs[dog.id] = dog
                }
            case .updateVisit(let visit):
                if resolvedVisits[visit.id] == nil ||
                   resolvedVisits[visit.id]?.updatedAt ?? Date.distantPast < visit.updatedAt {
                    resolvedVisits[visit.id] = visit
                }
            case .deleteDog(let dogId):
                resolvedDogs.removeValue(forKey: dogId)
            case .deleteVisit(let visitId):
                resolvedVisits.removeValue(forKey: visitId)
            case .checkoutDog(let dogId, let departureDate):
                if var visit = resolvedVisits.values.first(where: { $0.dogId == dogId && $0.departureDate == nil }) {
                    visit.departureDate = departureDate
                    visit.updatedAt = Date()
                    resolvedVisits[visit.id] = visit
                }
            }
        }
        
        // CRITICAL FIX: Merge CloudKit data with local cache, preserving pending operations
        // Instead of wholesale replacement, intelligently merge to preserve data integrity
        
        // Start with current cache state to preserve pending operations
        var mergedDogs = state.persistentDogs
        var mergedVisits = state.visits
        
        // Add/update confirmed CloudKit records
        for (dogId, cloudDog) in resolvedDogs {
            // Only update if we don't have a pending operation for this dog
            let hasPendingDogOperation = pendingOperations.values.contains { operation in
                switch operation.type {
                case .addDog(let pendingDog, _), .updateDog(let pendingDog):
                    return pendingDog.id == dogId
                case .deleteDog(let pendingDogId):
                    return pendingDogId == dogId
                case .updateVisit(let pendingVisit):
                    // Visit updates can affect dog's presence state
                    return pendingVisit.dogId == dogId
                case .deleteVisit(let pendingVisitId):
                    // Visit deletions can affect dog's presence state
                    return currentState.visits[pendingVisitId]?.dogId == dogId
                case .checkoutDog(let pendingDogId, _):
                    // Checkout operations affect dog's presence state
                    return pendingDogId == dogId
                }
            }
            
            if !hasPendingDogOperation {
                mergedDogs[dogId] = cloudDog
                #if DEBUG
                print("🔄 Merged dog from CloudKit: \(cloudDog.name)")
                #endif
            } else {
                #if DEBUG
                print("⏸️ Preserving pending operation for dog: \(mergedDogs[dogId]?.name ?? "Unknown")")
                #endif
            }
        }
        
        for (visitId, cloudVisit) in resolvedVisits {
            // Only update if we don't have a pending operation for this visit
            let hasPendingVisitOperation = pendingOperations.values.contains { operation in
                switch operation.type {
                case .addDog(_, let pendingVisit):
                    return pendingVisit.id == visitId
                case .updateVisit(let pendingVisit):
                    return pendingVisit.id == visitId
                case .deleteVisit(let pendingVisitId):
                    return pendingVisitId == visitId
                case .checkoutDog(let dogId, _):
                    return cloudVisit.dogId == dogId
                default:
                    return false
                }
            }
            
            if !hasPendingVisitOperation {
                mergedVisits[visitId] = cloudVisit
                #if DEBUG
                print("🔄 Merged visit from CloudKit for dog: \(cloudVisit.dogId)")
                #endif
            } else {
                #if DEBUG
                print("⏸️ Preserving pending operation for visit: \(visitId)")
                #endif
            }
        }
        
        // Apply the merged data (preserves pending operations)
        state.persistentDogs = mergedDogs
        state.visits = mergedVisits
        state.version += 1
        state.lastCloudKitSync = Date()
        
        #if DEBUG
        print("✅ Preserved \(pendingOperations.count) pending operations during sync")
        #endif
        
        // Log conflict resolutions for debugging
        if !conflictResolutions.isEmpty {
            #if DEBUG
            print("✅ DataIntegrityCache: Resolved \(conflictResolutions.count) conflicts during sync")
            for resolution in conflictResolutions {
                if let message = resolution.userMessage {
                    print("   - \(message)")
                }
            }
            #endif
        }
        
        #if DEBUG
        print("✅ DataIntegrityCache: CloudKit sync complete - cache version \(state.version)")
        #endif
    }
    
    // MARK: - Conflict Resolution Application
    
    /// Applies conflict resolution results to the resolved data
    private func applyConflictResolution(
        resolution: ConflictResolution,
        resolvedDogs: inout [UUID: PersistentDog],
        resolvedVisits: inout [UUID: Visit]
    ) {
        
        // Apply field updates
        for fieldUpdate in resolution.fieldUpdates {
            if fieldUpdate.fieldPath.starts(with: "persistentDog.") {
                // Update PersistentDog field
                if var dog = resolvedDogs[fieldUpdate.dogId] {
                    let fieldName = String(fieldUpdate.fieldPath.dropFirst("persistentDog.".count))
                    applyFieldUpdate(to: &dog, fieldName: fieldName, value: fieldUpdate.newValue)
                    resolvedDogs[fieldUpdate.dogId] = dog
                    
                    #if DEBUG
                    print("✅ Applied field update: \(fieldUpdate.fieldPath) = \(fieldUpdate.newValue)")
                    #endif
                }
            } else if fieldUpdate.fieldPath.starts(with: "currentVisit.") {
                // Update Visit field
                let fieldName = String(fieldUpdate.fieldPath.dropFirst("currentVisit.".count))
                if let visitId = resolvedVisits.values.first(where: { $0.dogId == fieldUpdate.dogId })?.id,
                   var visit = resolvedVisits[visitId] {
                    applyFieldUpdate(to: &visit, fieldName: fieldName, value: fieldUpdate.newValue)
                    resolvedVisits[visitId] = visit
                    
                    #if DEBUG
                    print("✅ Applied visit field update: \(fieldUpdate.fieldPath) = \(fieldUpdate.newValue)")
                    #endif
                }
            }
        }
        
        // Apply record merges
        for recordMerge in resolution.recordMerges {
            if let visitId = resolvedVisits.values.first(where: { $0.dogId == recordMerge.dogId })?.id,
               var visit = resolvedVisits[visitId] {
                
                applyRecordMerge(to: &visit, recordMerge: recordMerge)
                resolvedVisits[visitId] = visit
                
                #if DEBUG
                print("✅ Applied record merge: \(recordMerge.recordType) - added \(recordMerge.recordsToAdd.count) records")
                #endif
            }
        }
    }
    
    /// Applies a field update to a PersistentDog or Visit
    private func applyFieldUpdate<T>(to object: inout T, fieldName: String, value: Any) {
        // This is a simplified approach - in a real implementation, you'd use KeyPath or reflection
        // For now, we'll handle the most common fields explicitly
        
        if var dog = object as? PersistentDog {
            switch fieldName {
            case "ownerName":
                dog.ownerName = value as? String
            case "ownerPhoneNumber":
                dog.ownerPhoneNumber = value as? String
            default:
                #if DEBUG
                print("⚠️ Unhandled PersistentDog field: \(fieldName)")
                #endif
            }
            object = dog as! T
        } else if var visit = object as? Visit {
            switch fieldName {
            case "boardingEndDate":
                visit.boardingEndDate = value as? Date
            case "departureDate":
                visit.departureDate = value as? Date
            default:
                #if DEBUG
                print("⚠️ Unhandled Visit field: \(fieldName)")
                #endif
            }
            object = visit as! T
        }
    }
    
    /// Applies record merges to a Visit
    private func applyRecordMerge(to visit: inout Visit, recordMerge: RecordMerge) {
        switch recordMerge.recordType {
        case .feeding:
            if let feedingRecords = recordMerge.recordsToAdd as? [FeedingRecord] {
                visit.feedingRecords.append(contentsOf: feedingRecords)
                visit.feedingRecords.sort { $0.timestamp < $1.timestamp }
            }
        case .medication:
            if let medicationRecords = recordMerge.recordsToAdd as? [MedicationRecord] {
                visit.medicationRecords.append(contentsOf: medicationRecords)
                visit.medicationRecords.sort { $0.timestamp < $1.timestamp }
            }
        case .potty:
            if let pottyRecords = recordMerge.recordsToAdd as? [PottyRecord] {
                visit.pottyRecords.append(contentsOf: pottyRecords)
                visit.pottyRecords.sort { $0.timestamp < $1.timestamp }
            }
        case .scheduledMedication:
            if let scheduledMeds = recordMerge.recordsToAdd as? [ScheduledMedication] {
                visit.scheduledMedications.append(contentsOf: scheduledMeds)
                visit.scheduledMedications.sort { $0.scheduledDate < $1.scheduledDate }
            }
        }
        
        visit.updatedAt = Date()
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data (use with caution)
    func clearCache() {
        state = CacheState()
        pendingOperations.removeAll()
        
        #if DEBUG
        print("⚠️ DataIntegrityCache: Cache cleared - all data removed")
        #endif
    }
    
    /// Get cache statistics
    func getCacheStats() -> CacheStatistics {
        CacheStatistics(
            dogCount: state.persistentDogs.count,
            visitCount: state.visits.count,
            pendingOperations: pendingOperations.count,
            cacheVersion: state.version,
            lastSync: state.lastCloudKitSync
        )
    }
}

// MARK: - Supporting Types

enum DataIntegrityError: LocalizedError {
    case cloudKitSyncFailed(Error)
    case dataInconsistency(String)
    case conflictDetected(String)
    
    var errorDescription: String? {
        switch self {
        case .cloudKitSyncFailed(let error):
            return "Failed to sync with CloudKit: \(error.localizedDescription)"
        case .dataInconsistency(let message):
            return "Data inconsistency detected: \(message)"
        case .conflictDetected(let message):
            return "Conflict detected: \(message)"
        }
    }
}

struct IntegrityReport {
    var isValid: Bool = true
    var errors: [String] = []
    var warnings: [String] = []
    var cacheVersion: Int = 0
    var lastSync: Date = Date.distantPast
}

struct CacheStatistics {
    let dogCount: Int
    let visitCount: Int
    let pendingOperations: Int
    let cacheVersion: Int
    let lastSync: Date
}