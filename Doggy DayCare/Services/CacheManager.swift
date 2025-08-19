import Foundation

/// Timestamp-based cache system that works with CloudKit's natural design
/// Replaces the complex DataIntegrityCache with an efficient approach
@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    // MARK: - Cache Storage
    
    private var persistentDogs: [UUID: PersistentDog] = [:]
    private var visits: [UUID: Visit] = [:]
    private var lastSyncTime: Date = Date.distantPast
    
    private init() {
        #if DEBUG
        print("💾 CacheManager initialized with timestamp-based syncing")
        #endif
    }
    
    // MARK: - Cache Access
    
    func getAllPersistentDogs() -> [PersistentDog] {
        Array(persistentDogs.values)
    }
    
    func getAllVisits() -> [Visit] {
        Array(visits.values)
    }
    
    func getCurrentDogsWithVisits() -> [DogWithVisit] {
        return DogWithVisit.currentlyPresentFromPersistentDogsAndVisits(
            Array(persistentDogs.values),
            Array(visits.values)
        )
    }
    
    func getPersistentDog(id: UUID) -> PersistentDog? {
        return persistentDogs[id]
    }
    
    func getVisit(id: UUID) -> Visit? {
        return visits[id]
    }
    
    func getLastSyncTime() -> Date {
        return lastSyncTime
    }
    
    // MARK: - Intelligent Merging Logic
    
    /// Merges persistent dog data using timestamp-based "last writer wins" strategy
    func mergePersistentDog(local: PersistentDog?, remote: PersistentDog) {
        guard let local = local else {
            // No local version - accept remote
            persistentDogs[remote.id] = remote
            #if DEBUG
            print("💾 Added new dog to cache: \(remote.name)")
            #endif
            return
        }
        
        // Compare timestamps to determine which version to keep
        if remote.updatedAt > local.updatedAt {
            // Remote is newer - use remote version
            persistentDogs[remote.id] = remote
            #if DEBUG
            print("💾 Updated dog in cache (remote newer): \(remote.name)")
            #endif
        } else {
            // Local is same age or newer - keep local version
            #if DEBUG
            print("💾 Kept local dog (local newer): \(local.name)")
            #endif
        }
    }
    
    /// Merges visit data using timestamp-based strategy
    func mergeVisit(local: Visit?, remote: Visit) {
        guard let local = local else {
            // No local version - accept remote
            visits[remote.id] = remote
            #if DEBUG
            print("💾 Added new visit to cache for dog: \(remote.dogId)")
            #endif
            return
        }
        
        // Compare timestamps to determine which version to keep
        if remote.updatedAt > local.updatedAt {
            // Remote is newer - use remote version
            visits[remote.id] = remote
            #if DEBUG
            print("💾 Updated visit in cache (remote newer) for dog: \(remote.dogId)")
            #endif
        } else {
            // Local is same age or newer - keep local version
            #if DEBUG
            print("💾 Kept local visit (local newer) for dog: \(local.dogId)")
            #endif
        }
    }
    
    /// Batch merge data from CloudKit with intelligent timestamp comparison
    func mergeDataFromCloudKit(persistentDogs: [PersistentDog], visits: [Visit]) {
        #if DEBUG
        print("💾 Merging \(persistentDogs.count) dogs and \(visits.count) visits from CloudKit")
        #endif
        
        // Merge persistent dogs
        for remoteDog in persistentDogs {
            let localDog = self.persistentDogs[remoteDog.id]
            mergePersistentDog(local: localDog, remote: remoteDog)
        }
        
        // Merge visits
        for remoteVisit in visits {
            let localVisit = self.visits[remoteVisit.id]
            mergeVisit(local: localVisit, remote: remoteVisit)
        }
        
        // Update last sync time
        lastSyncTime = Date()
        
        #if DEBUG
        print("💾 Merge complete - cache now has \(self.persistentDogs.count) dogs and \(self.visits.count) visits")
        #endif
    }
    
    // MARK: - Optimistic Updates
    
    /// Update local cache immediately for optimistic UI updates
    func updateLocalPersistentDog(_ dog: PersistentDog) {
        persistentDogs[dog.id] = dog
        #if DEBUG
        print("💾 Optimistic update: \(dog.name)")
        #endif
    }
    
    /// Update local visit immediately for optimistic UI updates
    func updateLocalVisit(_ visit: Visit) {
        visits[visit.id] = visit
        #if DEBUG
        print("💾 Optimistic visit update for dog: \(visit.dogId)")
        #endif
    }
    
    /// Add new dog and visit to local cache immediately
    func addLocalDogWithVisit(persistentDog: PersistentDog, visit: Visit) {
        persistentDogs[persistentDog.id] = persistentDog
        visits[visit.id] = visit
        #if DEBUG
        print("💾 Optimistic add: \(persistentDog.name)")
        #endif
    }
    
    /// Remove visit from local cache immediately
    func removeLocalVisit(_ visitId: UUID) {
        visits.removeValue(forKey: visitId)
        #if DEBUG
        print("💾 Optimistic remove visit: \(visitId)")
        #endif
    }
    
    // MARK: - Error Recovery
    
    /// Revert optimistic update if CloudKit operation fails
    func revertDogUpdate(to previousDog: PersistentDog) {
        persistentDogs[previousDog.id] = previousDog
        #if DEBUG
        print("💾 Reverted dog update: \(previousDog.name)")
        #endif
    }
    
    /// Revert optimistic visit update if CloudKit operation fails
    func revertVisitUpdate(to previousVisit: Visit) {
        visits[previousVisit.id] = previousVisit
        #if DEBUG
        print("💾 Reverted visit update for dog: \(previousVisit.dogId)")
        #endif
    }
    
    /// Remove dog/visit if optimistic add fails
    func revertDogAddition(dogId: UUID, visitId: UUID) {
        persistentDogs.removeValue(forKey: dogId)
        visits.removeValue(forKey: visitId)
        #if DEBUG
        print("💾 Reverted dog addition: \(dogId)")
        #endif
    }
    
    /// Restore visit if optimistic delete fails
    func revertVisitDeletion(_ visit: Visit) {
        visits[visit.id] = visit
        #if DEBUG
        print("💾 Reverted visit deletion: \(visit.id)")
        #endif
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data (for logout or reset)
    func clearCache() {
        persistentDogs.removeAll()
        visits.removeAll()
        lastSyncTime = Date.distantPast
        
        #if DEBUG
        print("💾 Cache cleared")
        #endif
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> (dogCount: Int, visitCount: Int, lastSync: Date) {
        return (dogCount: persistentDogs.count, visitCount: visits.count, lastSync: lastSyncTime)
    }
}