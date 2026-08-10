import Foundation
import WatchConnectivity
import WatchKit
import os.log

class WatchBackgroundSyncManager: NSObject, ObservableObject {
    static let shared = WatchBackgroundSyncManager()
    
    private var backgroundTask: WKWatchConnectivityRefreshBackgroundTask?
    private let connectivityManager = WatchConnectivityManager.shared
    private let cloudBackup = WatchCloudBackupManager.shared
    
    private override init() {
        super.init()
    }
    
    // MARK: - Background Task Handling
    
    func handleBackgroundTask(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        backgroundTask = task
        
        os_log("Background sync task started", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info)
        
        // Perform sync operations
        performBackgroundSync { [weak self] success in
            self?.completeBackgroundTask(success: success)
        }
    }
    
    private func completeBackgroundTask(success: Bool) {
        backgroundTask?.setTaskCompletedWithSnapshot(false)
        backgroundTask = nil
        
        os_log("Background sync task completed with success: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info, success ? 1 : 0)
    }
    
    // MARK: - Schedule Background Sync
    
    func scheduleBackgroundSync() {
        let userInfo = ["reason": "periodic_sync"] as NSDictionary
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(1800), // 30 minutes
            userInfo: userInfo as? (NSSecureCoding & NSObjectProtocol)
        ) { error in
            if let error = error {
                os_log("Failed to schedule background refresh: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .error, error.localizedDescription)
            } else {
                os_log("Background refresh scheduled", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info)
            }
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func triggerImmediateSync() {
        os_log("Triggering immediate sync", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info)
        
        performBackgroundSync { success in
            os_log("Immediate sync completed with success: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info, success ? 1 : 0)
        }
    }
    
    // MARK: - Sync on App State Changes
    
    func handleAppStateChange(to state: WKApplicationState) {
        switch state {
        case .active:
            // App is active, perform immediate sync
            triggerImmediateSync()
        case .inactive:
            // App is inactive, schedule background sync
            scheduleBackgroundSync()
        case .background:
            // App is in background, sync will be handled by background task
            os_log("App in background, waiting for background task", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info)
        @unknown default:
            break
        }
    }
    
    // MARK: - Sync Priority Management
    
    enum SyncPriority {
        case critical // Active workout, immediate sync
        case high // User-initiated sync
        case normal // Periodic sync
        case low // Background maintenance
    }
    
    func syncWithPriority(_ priority: SyncPriority) {
        switch priority {
        case .critical:
            // Immediate sync, no delays
            performBackgroundSync { _ in }
        case .high:
            // High priority, minimal delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.triggerImmediateSync()
            }
        case .normal:
            // Normal priority, standard behavior
            triggerImmediateSync()
        case .low:
            // Low priority, schedule for later
            scheduleBackgroundSync()
        }
    }
    
    // MARK: - Sync Status Monitoring
    
    private var lastSyncTime: Date?
    private var syncInProgress = false
    
    var isSyncInProgress: Bool {
        return syncInProgress
    }
    
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastSyncTime else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    private func performBackgroundSync(completion: @escaping (Bool) -> Void) {
        guard !syncInProgress else {
            os_log("Sync already in progress, skipping", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .error)
            completion(false)
            return
        }
        
        syncInProgress = true
        lastSyncTime = Date()
        
        let group = DispatchGroup()
        var syncSuccess = true
        
        // 1. Sync offline workouts
        group.enter()
        connectivityManager.syncOfflineWorkouts()
        group.leave()
        
        // 2. Sync to iCloud
        group.enter()
        cloudBackup.syncToCloud()
        group.leave()
        
        // 3. Sync from iCloud if needed
        group.enter()
        let cache = WatchDataCache.shared
        if cache.getRoutines().isEmpty {
            cloudBackup.syncFromCloud()
        }
        group.leave()
        
        // 4. Request sync from iPhone if reachable
        if WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isReachable {
            group.enter()
            connectivityManager.requestSync()
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            os_log("Background sync completed", log: OSLog(subsystem: "com.losmooscles.watch", category: "BackgroundSync"), type: .info)
            self?.syncInProgress = false
            completion(syncSuccess)
        }
    }
}

// MARK: - Extension Delegate Integration

extension WatchBackgroundSyncManager {
    static func setupBackgroundSync() {
        let manager = shared
        
        // Schedule initial background sync
        manager.scheduleBackgroundSync()
        
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            forName: WKApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            manager.handleAppStateChange(to: .active)
        }
        
        NotificationCenter.default.addObserver(
            forName: WKApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            manager.handleAppStateChange(to: .background)
        }
    }
}
