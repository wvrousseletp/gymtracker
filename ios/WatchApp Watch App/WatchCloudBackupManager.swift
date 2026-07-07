import Foundation
import os.log

class WatchCloudBackupManager {
    static let shared = WatchCloudBackupManager()
    
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let cache = WatchDataCache.shared
    private let syncQueue = DispatchQueue(label: "com.losmooscles.watch.cloud", qos: .utility)
    
    // Keys for iCloud storage
    private enum CloudKey: String {
        case routines = "cloud_routines"
        case library = "cloud_library"
        case planner = "cloud_planner"
        case streak = "cloud_streak"
        case waterTarget = "cloud_water_target"
        case lastSync = "cloud_last_sync"
        case version = "cloud_version"
    }
    
    private let currentVersion = "1.0"
    
    private init() {
        setupCloudNotifications()
    }
    
    // MARK: - Setup
    
    private func setupCloudNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
    }
    
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        switch reason {
        case NSUbiquitousKeyValueStoreAccountChange, NSUbiquitousKeyValueStoreInitialSyncChange, NSUbiquitousKeyValueStoreQuotaViolationChange:
            os_log("iCloud sync changed: reason %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, reason)
            syncFromCloud()
        case NSUbiquitousKeyValueStoreServerChange:
            os_log("iCloud data changed on server", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            syncFromCloud()
        default:
            break
        }
    }
    
    // MARK: - Upload to iCloud
    
    func syncToCloud() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            os_log("Starting sync to iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            
            // Upload routines
            let routines = self.cache.getRoutines()
            if let routinesData = try? JSONEncoder().encode(routines),
               let routinesString = String(data: routinesData, encoding: .utf8) {
                self.iCloudStore.set(routinesString, forKey: CloudKey.routines.rawValue)
            }
            
            // Upload library (truncated if too large)
            let library = self.cache.getLibrary()
            let truncatedLibrary = Array(library.prefix(50)) // Limit to 50 exercises
            if let libraryData = try? JSONEncoder().encode(truncatedLibrary),
               let libraryString = String(data: libraryData, encoding: .utf8) {
                self.iCloudStore.set(libraryString, forKey: CloudKey.library.rawValue)
            }
            
            // Upload planner
            let planner = self.cache.getPlanner()
            if let plannerData = try? JSONEncoder().encode(planner),
               let plannerString = String(data: plannerData, encoding: .utf8) {
                self.iCloudStore.set(plannerString, forKey: CloudKey.planner.rawValue)
            }
            
            // Upload streak
            let streak = self.cache.getStreak()
            if let streakData = try? JSONEncoder().encode(streak),
               let streakString = String(data: streakData, encoding: .utf8) {
                self.iCloudStore.set(streakString, forKey: CloudKey.streak.rawValue)
            }
            
            // Upload water target
            let waterTarget = self.cache.getWaterIntakeTarget()
            self.iCloudStore.set(waterTarget, forKey: CloudKey.waterTarget.rawValue)
            
            // Upload version and timestamp
            self.iCloudStore.set(self.currentVersion, forKey: CloudKey.version.rawValue)
            self.iCloudStore.set(Int64(Date().timeIntervalSince1970), forKey: CloudKey.lastSync.rawValue)
            
            self.iCloudStore.synchronize()
            
            os_log("Sync to iCloud completed", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
        }
    }
    
    // MARK: - Download from iCloud
    
    func syncFromCloud() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            os_log("Starting sync from iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            
            // Check version compatibility
            let cloudVersion = self.iCloudStore.string(forKey: CloudKey.version.rawValue)
            if cloudVersion != self.currentVersion {
                os_log("Version mismatch: local=%s, cloud=%s", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .error, self.currentVersion, cloudVersion ?? "nil")
            }
            
            // Download routines if local is empty or cloud is newer
            let localRoutines = self.cache.getRoutines()
            if localRoutines.isEmpty,
               let routinesString = self.iCloudStore.string(forKey: CloudKey.routines.rawValue),
               let routinesData = routinesString.data(using: .utf8),
               let routines = try? JSONDecoder().decode([WatchRoutine].self, from: routinesData) {
                self.cache.setRoutines(routines)
                os_log("Restored %d routines from iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, routines.count)
            }
            
            // Download library if local is empty
            let localLibrary = self.cache.getLibrary()
            if localLibrary.isEmpty,
               let libraryString = self.iCloudStore.string(forKey: CloudKey.library.rawValue),
               let libraryData = libraryString.data(using: .utf8),
               let library = try? JSONDecoder().decode([WatchLibraryExercise].self, from: libraryData) {
                self.cache.setLibrary(library)
                os_log("Restored %d library exercises from iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, library.count)
            }
            
            // Download planner if local is empty
            let localPlanner = self.cache.getPlanner()
            if localPlanner.isEmpty,
               let plannerString = self.iCloudStore.string(forKey: CloudKey.planner.rawValue),
               let plannerData = plannerString.data(using: .utf8),
               let planner = try? JSONDecoder().decode([String: [String]].self, from: plannerData) {
                self.cache.setPlanner(planner)
                os_log("Restored planner from iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            }
            
            // Download streak if local is default
            let localStreak = self.cache.getStreak()
            if localStreak.currentWeekCount == 0 && localStreak.consecutiveWeeks == 0,
               let streakString = self.iCloudStore.string(forKey: CloudKey.streak.rawValue),
               let streakData = streakString.data(using: .utf8),
               let streak = try? JSONDecoder().decode(WatchStreak.self, from: streakData) {
                self.cache.setStreak(streak)
                os_log("Restored streak from iCloud", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            }
            
            // Download water target
            let cloudWaterTarget = self.iCloudStore.integer(forKey: CloudKey.waterTarget.rawValue)
            if cloudWaterTarget > 0 {
                self.cache.setWaterIntakeTarget(cloudWaterTarget)
                os_log("Restored water target from iCloud: %d ml", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, cloudWaterTarget)
            }
            
            os_log("Sync from iCloud completed", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
        }
    }
    
    // MARK: - Manual Backup/Restore
    
    func exportBackupData() -> String? {
        let backup: [String: Any] = [
            "version": currentVersion,
            "timestamp": Int64(Date().timeIntervalSince1970),
            "routines": cache.getRoutines(),
            "library": Array(cache.getLibrary().prefix(50)),
            "planner": cache.getPlanner(),
            "streak": cache.getStreak(),
            "waterTarget": cache.getWaterIntakeTarget()
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: backup, options: [.prettyPrinted]),
              let jsonString = String(data: data, encoding: .utf8) else {
            os_log("Failed to export backup data", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .error)
            return nil
        }
        
        os_log("Exported backup data: %d bytes", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, jsonString.count)
        return jsonString
    }
    
    func restoreFromBackup(jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let backup = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            os_log("Failed to parse backup data", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .error)
            return false
        }
        
        // Restore routines
        if let routinesArray = backup["routines"] as? [[String: Any]] {
            let routinesData = try? JSONSerialization.data(withJSONObject: routinesArray)
            if let data = routinesData,
               let routines = try? JSONDecoder().decode([WatchRoutine].self, from: data) {
                cache.setRoutines(routines)
                os_log("Restored %d routines from backup", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, routines.count)
            }
        }
        
        // Restore library
        if let libraryArray = backup["library"] as? [[String: Any]] {
            let libraryData = try? JSONSerialization.data(withJSONObject: libraryArray)
            if let data = libraryData,
               let library = try? JSONDecoder().decode([WatchLibraryExercise].self, from: data) {
                cache.setLibrary(library)
                os_log("Restored %d library exercises from backup", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, library.count)
            }
        }
        
        // Restore planner
        if let plannerDict = backup["planner"] as? [String: [String]] {
            cache.setPlanner(plannerDict)
            os_log("Restored planner from backup", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
        }
        
        // Restore streak
        if let streakDict = backup["streak"] as? [String: Any] {
            let streakData = try? JSONSerialization.data(withJSONObject: streakDict)
            if let data = streakData,
               let streak = try? JSONDecoder().decode(WatchStreak.self, from: data) {
                cache.setStreak(streak)
                os_log("Restored streak from backup", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info)
            }
        }
        
        // Restore water target
        if let waterTarget = backup["waterTarget"] as? Int {
            cache.setWaterIntakeTarget(waterTarget)
            os_log("Restored water target from backup: %d ml", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cloud"), type: .info, waterTarget)
        }
        
        return true
    }
    
    // MARK: - Status
    
    func getLastSyncTimestamp() -> Int64? {
        return iCloudStore.object(forKey: CloudKey.lastSync.rawValue) as? Int64
    }
    
    func isCloudAvailable() -> Bool {
        return iCloudStore.synchronize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
