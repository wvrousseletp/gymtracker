import Foundation
import os.log

class WatchLocalWorkoutManager {
    static let shared = WatchLocalWorkoutManager()
    
    private var offlineWorkoutQueue: [OfflineWorkoutItem] = []
    private let cache = WatchDataCache.shared
    
    private init() {
        loadOfflineQueue()
    }
    
    // MARK: - Offline Workout Queue
    
    struct OfflineWorkoutItem: Codable {
        let id: String
        let workoutData: WatchActiveWorkoutState
        let timestamp: Int64
        let synced: Bool
        
        init(id: String = UUID().uuidString, workoutData: WatchActiveWorkoutState, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), synced: Bool = false) {
            self.id = id
            self.workoutData = workoutData
            self.timestamp = timestamp
            self.synced = synced
        }
    }
    
    private func loadOfflineQueue() {
        guard let jsonString = cache.userDefaults.string(forKey: "offline_workout_queue"),
              let jsonData = jsonString.data(using: .utf8) else {
            return
        }
        
        do {
            offlineWorkoutQueue = try JSONDecoder().decode([OfflineWorkoutItem].self, from: jsonData)
            os_log("Loaded %d offline workouts from queue", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, offlineWorkoutQueue.count)
        } catch {
            os_log("Failed to load offline queue: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .error, error.localizedDescription)
        }
    }
    
    private func saveOfflineQueue() {
        do {
            let encoded = try JSONEncoder().encode(offlineWorkoutQueue)
            if let jsonString = String(data: encoded, encoding: .utf8) {
                cache.userDefaults.set(jsonString, forKey: "offline_workout_queue")
                cache.userDefaults.synchronize()
            }
        } catch {
            os_log("Failed to save offline queue: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .error, error.localizedDescription)
        }
    }
    
    func addToOfflineQueue(workout: WatchActiveWorkoutState) {
        let item = OfflineWorkoutItem(workoutData: workout)
        offlineWorkoutQueue.append(item)
        saveOfflineQueue()
        os_log("Added workout '%s' to offline queue", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, workout.name)
    }
    
    func removeFromOfflineQueue(workoutId: String) {
        offlineWorkoutQueue.removeAll { $0.id == workoutId }
        saveOfflineQueue()
        os_log("Removed workout %s from offline queue", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, workoutId)
    }
    
    func markAsSynced(workoutId: String) {
        if let index = offlineWorkoutQueue.firstIndex(where: { $0.id == workoutId }) {
            offlineWorkoutQueue[index] = OfflineWorkoutItem(
                id: offlineWorkoutQueue[index].id,
                workoutData: offlineWorkoutQueue[index].workoutData,
                timestamp: offlineWorkoutQueue[index].timestamp,
                synced: true
            )
            saveOfflineQueue()
        }
    }
    
    func getPendingSyncWorkouts() -> [OfflineWorkoutItem] {
        return offlineWorkoutQueue.filter { !$0.synced }
    }
    
    func clearSyncedWorkouts() {
        offlineWorkoutQueue.removeAll { $0.synced }
        saveOfflineQueue()
        os_log("Cleared synced workouts from queue", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info)
    }
    
    // MARK: - Local Workout Operations
    
    func startLocalWorkout(routineId: String, customExercises: [[String: Any]]? = nil, routines: [WatchRoutine], library: [WatchLibraryExercise]) -> WatchActiveWorkoutState? {
        guard let routine = routines.first(where: { $0.id == routineId }) else {
            os_log("Routine not found: %s", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .error, routineId)
            return nil
        }
        
        var activeExercises: [WatchActiveExercise] = []
        for re in routine.exercises {
            let libEx = library.first(where: { $0.id == re.exerciseId })
            let name = libEx?.name ?? "Exercício"
            let muscle = libEx?.muscle ?? "Geral"
            let measurementType = libEx?.measurementType ?? "reps"
            let executionType = libEx?.executionType
            
            var targetSets = re.sets
            var targetReps = re.reps
            var targetWeight = re.weight
            
            if let custom = customExercises?.first(where: { ($0["exerciseId"] as? String) == re.exerciseId }) {
                targetSets = custom["sets"] as? Int ?? re.sets
                targetReps = custom["reps"] as? Int ?? re.reps
                targetWeight = custom["weight"] as? Double ?? re.weight
            }
            
            let activeEx = WatchActiveExercise(
                name: name,
                muscle: muscle,
                sets: targetSets,
                reps: targetReps,
                rest: re.rest,
                weight: targetWeight,
                setsState: Array(repeating: false, count: targetSets),
                measurementType: measurementType,
                executionType: executionType,
                performedCardios: Array(repeating: nil, count: targetSets),
                failureReport: Array(repeating: false, count: targetSets),
                failureReps: Array(repeating: nil, count: targetSets)
            )
            activeExercises.append(activeEx)
        }
        
        let state = WatchActiveWorkoutState(
            name: routine.name,
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            exercises: activeExercises,
            currentExerciseIndex: 0,
            elapsedSeconds: 0,
            paused: false,
            restTimer: nil,
            postponed: false
        )
        
        cache.setLocalWorkoutState(state)
        cache.setLocalWorkout(true)
        
        // Note: HealthKit workout should be started by the caller
        // WorkoutManager.shared.startWorkout(exercises: activeExercises)
        
        os_log("Started local workout: %s", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, routine.name)
        return state
    }
    
    func startLocalSingleExercise(exerciseId: String, library: [WatchLibraryExercise]) -> WatchActiveWorkoutState? {
        guard let libEx = library.first(where: { $0.id == exerciseId }) else {
            os_log("Exercise not found: %s", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .error, exerciseId)
            return nil
        }
        
        let activeEx = WatchActiveExercise(
            name: libEx.name,
            muscle: libEx.muscle,
            sets: 3,
            reps: 10,
            rest: 60,
            weight: 0.0,
            setsState: [false, false, false],
            measurementType: libEx.measurementType,
            executionType: libEx.executionType,
            performedCardios: [nil, nil, nil],
            failureReport: [false, false, false],
            failureReps: [nil, nil, nil]
        )
        
        let state = WatchActiveWorkoutState(
            name: libEx.name,
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            exercises: [activeEx],
            currentExerciseIndex: 0,
            elapsedSeconds: 0,
            paused: false,
            restTimer: nil,
            postponed: false
        )
        
        cache.setLocalWorkoutState(state)
        cache.setLocalWorkout(true)
        
        // Note: HealthKit workout should be started by the caller
        // WorkoutManager.shared.startWorkout(exercises: [activeEx])
        
        os_log("Started local single exercise: %s", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, libEx.name)
        return state
    }
    
    func updateLocalWorkout(_ state: WatchActiveWorkoutState) {
        cache.setLocalWorkoutState(state)
    }
    
    func clearLocalWorkout() {
        cache.setLocalWorkoutState(nil)
        cache.setLocalWorkout(false)
        os_log("Cleared local workout", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info)
    }
    
    func getLocalWorkout() -> WatchActiveWorkoutState? {
        return cache.getLocalWorkoutState()
    }
    
    // MARK: - Workout Completion
    
    func completeLocalWorkout(activeWorkout: WatchActiveWorkoutState, rpe: Int = 8, notes: String = "Treino concluído em modo offline via Apple Watch") -> [String: Any] {
        let now = Date()
        let duration = max(0, Int(now.timeIntervalSince1970 - Double(activeWorkout.startTime / 1000)))
        
        var totalSets = 0
        var completedSets = 0
        var totalWeightVolume = 0.0
        
        var exercisesJson: [[String: Any]] = []
        
        for ex in activeWorkout.exercises {
            let done = ex.setsState.filter { $0 }.count
            totalSets += ex.sets
            completedSets += done
            
            let isCardio = ex.isCardio
            
            if !isCardio {
                totalWeightVolume += Double(done) * ex.weight
            }
            
            var setsJson: [[String: Any]] = []
            for (idx, isDone) in ex.setsState.enumerated() {
                var setDict: [String: Any] = [
                    "index": idx,
                    "completed": isDone
                ]
                
                if isCardio, idx < ex.performedCardios.count, let cardio = ex.performedCardios[idx] {
                    setDict["distance"] = cardio.distanceKm
                    setDict["duration"] = cardio.durationSeconds
                } else {
                    setDict["weight"] = ex.weight
                    setDict["reps"] = ex.reps
                    
                    if idx < ex.failureReport.count, ex.failureReport[idx] {
                        setDict["failure"] = true
                        if idx < ex.failureReps.count, let failureRep = ex.failureReps[idx] {
                            setDict["failureReps"] = failureRep
                        }
                    }
                }
                setsJson.append(setDict)
            }
            
            let exDict: [String: Any] = [
                "name": ex.name,
                "muscle": ex.muscle,
                "sets": setsJson,
                "measurementType": ex.measurementType,
                "executionType": ex.executionType ?? "Livre"
            ]
            exercisesJson.append(exDict)
        }
        
        let workoutDict: [String: Any] = [
            "id": UUID().uuidString,
            "name": activeWorkout.name,
            "startTime": activeWorkout.startTime,
            "endTime": Int64(now.timeIntervalSince1970 * 1000),
            "duration": duration,
            "totalSets": totalSets,
            "completedSets": completedSets,
            "totalWeightVolume": totalWeightVolume,
            "rpe": rpe,
            "notes": notes,
            "exercises": exercisesJson,
            "isOffline": true
        ]
        
        // Add to offline queue for sync
        addToOfflineQueue(workout: activeWorkout)
        
        // Backup to HealthKit
        HealthKitWorkoutManager.shared.saveWorkoutToHealthKit(workoutData: workoutDict) { success, error in
            if success {
                os_log("Workout backed up to HealthKit", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info)
            } else if let error = error {
                os_log("Failed to backup workout to HealthKit: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .error, error.localizedDescription)
            }
        }
        
        // Clear local workout
        clearLocalWorkout()
        
        os_log("Completed local workout: %s", log: OSLog(subsystem: "com.losmooscles.watch", category: "LocalWorkout"), type: .info, activeWorkout.name)
        return workoutDict
    }
}
