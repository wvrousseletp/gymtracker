import Foundation
import os.log

class WatchDataCache {
    static let shared = WatchDataCache()
    
    let userDefaults: UserDefaults
    private let cacheQueue = DispatchQueue(label: "com.losmooscles.watch.cache", qos: .utility)
    
    // In-memory cache with debouncing
    private var memoryCache: [String: Any] = [:]
    private var pendingWrites: [String: Any] = [:]
    private var writeTimer: Timer?
    private let writeDelay: TimeInterval = 2.0
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        startWriteTimer()
    }
    
    // MARK: - Public API
    
    func getRoutines() -> [WatchRoutine] {
        if let cached = memoryCache["routines"] as? [WatchRoutine] {
            return cached
        }
        
        guard let jsonString = userDefaults.string(forKey: "cached_routines"),
              let jsonData = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            let routines = try JSONDecoder().decode([WatchRoutine].self, from: jsonData)
            memoryCache["routines"] = routines
            return routines
        } catch {
            os_log("Failed to decode routines: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .error, error.localizedDescription)
            return []
        }
    }
    
    func setRoutines(_ routines: [WatchRoutine]) {
        memoryCache["routines"] = routines
        scheduleWrite(key: "cached_routines", value: routines)
    }
    
    func getLibrary() -> [WatchLibraryExercise] {
        if let cached = memoryCache["library"] as? [WatchLibraryExercise] {
            return cached
        }
        
        guard let jsonString = userDefaults.string(forKey: "cached_library"),
              let jsonData = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            let library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
            memoryCache["library"] = library
            return library
        } catch {
            os_log("Failed to decode library: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .error, error.localizedDescription)
            return []
        }
    }
    
    func setLibrary(_ library: [WatchLibraryExercise]) {
        memoryCache["library"] = library
        scheduleWrite(key: "cached_library", value: library)
    }
    
    func getPlanner() -> [String: [String]] {
        if let cached = memoryCache["planner"] as? [String: [String]] {
            return cached
        }
        
        guard let jsonString = userDefaults.string(forKey: "cached_planner"),
              let jsonData = jsonString.data(using: .utf8) else {
            return [:]
        }
        
        do {
            let planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
            memoryCache["planner"] = planner
            return planner
        } catch {
            os_log("Failed to decode planner: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .error, error.localizedDescription)
            return [:]
        }
    }
    
    func setPlanner(_ planner: [String: [String]]) {
        memoryCache["planner"] = planner
        scheduleWrite(key: "cached_planner", value: planner)
    }
    
    func getStreak() -> WatchStreak {
        if let cached = memoryCache["streak"] as? WatchStreak {
            return cached
        }
        
        guard let jsonString = userDefaults.string(forKey: "cached_streak"),
              let jsonData = jsonString.data(using: .utf8) else {
            return WatchStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: "")
        }
        
        do {
            let streak = try JSONDecoder().decode(WatchStreak.self, from: jsonData)
            memoryCache["streak"] = streak
            return streak
        } catch {
            os_log("Failed to decode streak: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .error, error.localizedDescription)
            return WatchStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: "")
        }
    }
    
    func setStreak(_ streak: WatchStreak) {
        memoryCache["streak"] = streak
        scheduleWrite(key: "cached_streak", value: streak)
    }
    
    func getWaterIntakeCurrent() -> Int {
        if let cached = memoryCache["water_current"] as? Int {
            return cached
        }
        return userDefaults.integer(forKey: "cached_water_intake")
    }
    
    func setWaterIntakeCurrent(_ value: Int) {
        memoryCache["water_current"] = value
        scheduleWrite(key: "cached_water_intake", value: value)
    }
    
    func getWaterIntakeTarget() -> Int {
        if let cached = memoryCache["water_target"] as? Int {
            return cached
        }
        let cached = userDefaults.integer(forKey: "cached_water_target")
        return cached > 0 ? cached : 2000
    }
    
    func setWaterIntakeTarget(_ value: Int) {
        memoryCache["water_target"] = value
        scheduleWrite(key: "cached_water_target", value: value)
    }
    
    func getWaterDate() -> String {
        return userDefaults.string(forKey: "cached_water_date") ?? ""
    }
    
    func setWaterDate(_ date: String) {
        scheduleWrite(key: "cached_water_date", value: date)
    }
    
    func getLocalWorkoutState() -> WatchActiveWorkoutState? {
        guard let savedData = userDefaults.data(forKey: "local_workout_state") else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(WatchActiveWorkoutState.self, from: savedData)
        } catch {
            os_log("Failed to decode local workout: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .error, error.localizedDescription)
            return nil
        }
    }
    
    func setLocalWorkoutState(_ state: WatchActiveWorkoutState?) {
        if let state = state {
            if let encoded = try? JSONEncoder().encode(state) {
                scheduleWrite(key: "local_workout_state", value: encoded)
            }
        } else {
            scheduleWrite(key: "local_workout_state", value: nil)
        }
    }
    
    func isLocalWorkout() -> Bool {
        return userDefaults.bool(forKey: "local_workout_is_local")
    }
    
    func setLocalWorkout(_ isLocal: Bool) {
        scheduleWrite(key: "local_workout_is_local", value: isLocal)
    }
    
    // MARK: - Private Methods
    
    private func scheduleWrite(key: String, value: Any?) {
        cacheQueue.async { [weak self] in
            self?.pendingWrites[key] = value
        }
    }
    
    private func startWriteTimer() {
        writeTimer = Timer.scheduledTimer(withTimeInterval: writeDelay, repeats: true) { [weak self] _ in
            self?.flushPendingWrites()
        }
    }
    
    private func flushPendingWrites() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.pendingWrites.isEmpty else { return }
            
            let writes = self.pendingWrites
            self.pendingWrites.removeAll()
            
            DispatchQueue.main.async {
                for (key, value) in writes {
                    if let stringValue = value as? String {
                        self.userDefaults.set(stringValue, forKey: key)
                    } else if let intValue = value as? Int {
                        self.userDefaults.set(intValue, forKey: key)
                    } else if let boolValue = value as? Bool {
                        self.userDefaults.set(boolValue, forKey: key)
                    } else if let dataValue = value as? Data {
                        self.userDefaults.set(dataValue, forKey: key)
                    } else if let codable = value as? Encodable {
                        if let encoded = try? JSONEncoder().encode(codable),
                           let jsonString = String(data: encoded, encoding: .utf8) {
                            self.userDefaults.set(jsonString, forKey: key)
                        }
                    } else {
                        // Value is nil, remove the key
                        self.userDefaults.removeObject(forKey: key)
                    }
                }
                self.userDefaults.synchronize()
                os_log("Flushed %d pending writes to UserDefaults", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .debug, writes.count)
            }
        }
    }
    
    func flushImmediately() {
        flushPendingWrites()
    }
    
    func clearAllCache() {
        memoryCache.removeAll()
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingWrites.removeAll()
            
            DispatchQueue.main.async {
                let domain = self.userDefaults.persistentDomain(forName: "group.com.vicente.losmooscles")
                self.userDefaults.removePersistentDomain(forName: "group.com.vicente.losmooscles")
                if let domain = domain {
                    self.userDefaults.setPersistentDomain(domain, forName: "group.com.vicente.losmooscles")
                }
                os_log("Cleared all cache", log: OSLog(subsystem: "com.losmooscles.watch", category: "Cache"), type: .info)
            }
        }
    }
}
