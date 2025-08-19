import Foundation
import UIKit

/// Handles scheduled syncing with CloudKit in the background
/// Manages foreground periodic sync, app lifecycle sync, and manual refresh
@MainActor
class SyncScheduler: ObservableObject {
    static let shared = SyncScheduler()
    
    // MARK: - Configuration
    
    private let foregroundSyncInterval: TimeInterval = 15.0 // 15 seconds in foreground
    private let minimumSyncInterval: TimeInterval = 1.0 // Minimum 1 second between syncs
    
    // MARK: - State
    
    private var foregroundSyncTimer: Timer?
    private var lastSyncTime: Date = Date.distantPast
    private var isSyncing: Bool = false
    
    // Dependencies
    private let cacheManager = CacheManager.shared
    private let persistentDogService = PersistentDogService.shared
    private let visitService = VisitService.shared
    
    private init() {
        setupAppLifecycleObservers()
        #if DEBUG
        print("🔄 SyncScheduler initialized")
        #endif
    }
    
    // MARK: - App Lifecycle Management
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        #if DEBUG
        print("🔄 App entering foreground - starting sync")
        #endif
        
        Task {
            await performIncrementalSync()
            startForegroundSync()
        }
    }
    
    @objc private func appDidEnterBackground() {
        #if DEBUG
        print("🔄 App entering background - stopping foreground sync")
        #endif
        
        stopForegroundSync()
    }
    
    @objc private func appDidBecomeActive() {
        #if DEBUG
        print("🔄 App became active - performing sync")
        #endif
        
        Task {
            await performIncrementalSync()
        }
    }
    
    // MARK: - Foreground Sync Management
    
    func startForegroundSync() {
        stopForegroundSync() // Stop any existing timer
        
        foregroundSyncTimer = Timer.scheduledTimer(withTimeInterval: foregroundSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performIncrementalSync()
            }
        }
        
        #if DEBUG
        print("🔄 Started foreground sync timer (every \(foregroundSyncInterval) seconds)")
        #endif
    }
    
    func stopForegroundSync() {
        foregroundSyncTimer?.invalidate()
        foregroundSyncTimer = nil
        
        #if DEBUG
        print("🔄 Stopped foreground sync timer")
        #endif
    }
    
    // MARK: - Manual Sync (Pull-to-Refresh)
    
    func performManualSync() async {
        #if DEBUG
        print("🔄 Manual sync requested")
        #endif
        
        await performIncrementalSync(forceSync: true)
    }
    
    // MARK: - Core Sync Logic
    
    /// Performs incremental sync using timestamp-based queries
    func performIncrementalSync(forceSync: Bool = false) async {
        // Prevent concurrent syncs
        guard !isSyncing else {
            #if DEBUG
            print("🔄 Sync already in progress - skipping")
            #endif
            return
        }
        
        // Respect minimum sync interval unless forced
        let timeSinceLastSync = Date().timeIntervalSince(lastSyncTime)
        if !forceSync && timeSinceLastSync < minimumSyncInterval {
            #if DEBUG
            print("🔄 Sync too recent (\(timeSinceLastSync)s ago) - skipping")
            #endif
            return
        }
        
        isSyncing = true
        lastSyncTime = Date()
        
        #if DEBUG
        print("🔄 Starting incremental sync...")
        #endif
        
        do {
            let lastCacheSync = cacheManager.getLastSyncTime()
            
            // Fetch only data modified since last sync
            let modifiedAfter = lastCacheSync == Date.distantPast ? nil : lastCacheSync
            
            #if DEBUG
            if let modifiedAfter = modifiedAfter {
                print("🔄 Fetching changes since: \(modifiedAfter)")
            } else {
                print("🔄 Performing initial full sync")
            }
            #endif
            
            // Fetch incremental changes - only active visits for scalability
            async let persistentDogsTask = persistentDogService.fetchPersistentDogs(modifiedAfter: modifiedAfter)
            async let visitsTask = visitService.fetchActiveVisits(modifiedAfter: modifiedAfter)
            
            let (persistentDogs, visits) = try await (persistentDogsTask, visitsTask)
            
            // Merge with local cache using intelligent timestamp comparison
            cacheManager.mergeDataFromCloudKit(persistentDogs: persistentDogs, visits: visits)
            
            #if DEBUG
            print("🔄 Incremental sync complete - fetched \(persistentDogs.count) dogs, \(visits.count) visits")
            #endif
            
        } catch {
            #if DEBUG
            print("🔄 Sync failed: \(error)")
            #endif
            
            // Don't update lastSyncTime on failure
            lastSyncTime = Date.distantPast
        }
        
        isSyncing = false
    }
    
    // MARK: - Initial Load
    
    /// Performs initial full data load on app startup
    func performInitialLoad() async {
        #if DEBUG
        print("🔄 Performing initial data load...")
        #endif
        
        do {
            // Load data for initial cache population - only active visits for scalability
            async let persistentDogsTask = persistentDogService.fetchPersistentDogs()
            async let visitsTask = visitService.fetchActiveVisits()
            
            let (persistentDogs, visits) = try await (persistentDogsTask, visitsTask)
            
            // Populate cache
            cacheManager.mergeDataFromCloudKit(persistentDogs: persistentDogs, visits: visits)
            
            #if DEBUG
            print("🔄 Initial load complete - loaded \(persistentDogs.count) dogs, \(visits.count) visits")
            #endif
            
            // Start foreground syncing after initial load
            startForegroundSync()
            
        } catch {
            #if DEBUG
            print("🔄 Initial load failed: \(error)")
            #endif
        }
    }
    
    // MARK: - Sync Status
    
    func getSyncStatus() -> (issyncing: Bool, lastSync: Date) {
        return (issyncing: isSyncing, lastSync: lastSyncTime)
    }
    
    // MARK: - Cleanup
    
    deinit {
        foregroundSyncTimer?.invalidate()
        foregroundSyncTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}