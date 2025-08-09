import Foundation
import SwiftUI

@MainActor
class AdvancedCache: ObservableObject {
    static let shared = AdvancedCache()
    
    // MARK: - Cache Levels
    
    private var memoryCache: [String: CachedItem] = [:]
    private let diskCache = DiskCache()
    private let maxMemoryItems = 100
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    // MARK: - Cache Item Structure
    
    struct CachedItem {
        let data: Any
        let timestamp: Date
        let expirationInterval: TimeInterval
        let accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expirationInterval
        }
        
        var shouldEvict: Bool {
            isExpired || accessCount < 2 // Evict rarely accessed items
        }
    }
    
    private init() {
        // Load disk cache on initialization
        Task {
            await diskCache.loadCache()
        }
    }
    
    // MARK: - Cache Operations
    
    func set<T: Codable>(_ value: T, for key: String, expirationInterval: TimeInterval = 3600) {
        let item = CachedItem(
            data: value,
            timestamp: Date(),
            expirationInterval: expirationInterval,
            accessCount: 1
        )
        
        // Store in memory cache
        memoryCache[key] = item
        
        // Store in disk cache for persistence
        Task {
            await diskCache.set(value, for: key)
        }
        
        // Evict old items if cache is full
        if memoryCache.count > maxMemoryItems {
            evictOldItems()
        }
        
        #if DEBUG
        print("💾 Cached \(key) (memory + disk)")
        #endif
    }
    
    func get<T: Codable>(_ key: String) async -> T? {
        // Check memory cache first
        if let item = memoryCache[key] {
            if item.isExpired {
                memoryCache.removeValue(forKey: key)
                return nil
            }
            
            // Update access count
            let updatedItem = CachedItem(
                data: item.data,
                timestamp: item.timestamp,
                expirationInterval: item.expirationInterval,
                accessCount: item.accessCount + 1
            )
            memoryCache[key] = updatedItem
            
            return item.data as? T
        }
        
        // Check disk cache
        return await diskCache.get(key)
    }
    
    func remove(_ key: String) {
        memoryCache.removeValue(forKey: key)
        Task {
            await diskCache.remove(key)
        }
        #if DEBUG
        print("🗑️ Removed cache for \(key)")
        #endif
    }
    
    func clear() {
        memoryCache.removeAll()
        Task {
            await diskCache.clear()
        }
        #if DEBUG
        print("🧹 Cache cleared")
        #endif
    }
    
    // MARK: - Cache Management
    
    private func evictOldItems() {
        let itemsToEvict = memoryCache.filter { $0.value.shouldEvict }
        
        for (key, _) in itemsToEvict {
            memoryCache.removeValue(forKey: key)
        }
        
        if !itemsToEvict.isEmpty {
            #if DEBUG
            print("🗑️ Evicted \(itemsToEvict.count) old cache items")
            #endif
        }
    }
    
    func getCacheStats() async -> (memoryCount: Int, diskSize: String) {
        let diskSize = await diskCache.getSize()
        return (memoryCache.count, diskSize)
    }
}

// MARK: - Disk Cache

actor DiskCache {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("AdvancedCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func set<T: Codable>(_ value: T, for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
        } catch {
            #if DEBUG
            print("❌ Failed to write cache for \(key): \(error)")
            #endif
        }
    }
    
    func get<T: Codable>(_ key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Failed to read cache for \(key): \(error)")
            #endif
            return nil
        }
    }
    
    func remove(_ key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clear() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func loadCache() async {
        // Preload frequently accessed items into memory
        let frequentlyAccessedKeys = ["dogs_basic", "users_basic", "schema_version"]
        
        for key in frequentlyAccessedKeys {
            if let _: Data = get(key) {
                // Note: This will be handled by the main AdvancedCache initialization
                // We just ensure the data is available on disk
                #if DEBUG
                print("📁 Preloaded cache data for \(key)")
                #endif
            }
        }
    }
    
    func getSize() async -> String {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize: Int64 = 0
            
            for fileURL in contents {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        } catch {
            return "0 KB"
        }
    }
} 