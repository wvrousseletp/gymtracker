import Foundation
import HealthKit
import os.log

class HealthKitWorkoutManager {
    static let shared = HealthKitWorkoutManager()
    
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // Workout types
    private let traditionalStrengthWorkout = HKWorkoutActivityType.traditionalStrengthTraining
    private let cardioWorkout = HKWorkoutActivityType.other
    private let functionalStrengthWorkout = HKWorkoutActivityType.functionalStrengthTraining
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { typesToRead.insert(hr) }
        if let cal = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { typesToRead.insert(cal) }
        if let basal = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { typesToRead.insert(basal) }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { typesToRead.insert(steps) }
        if let dist = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { typesToRead.insert(dist) }
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                os_log("HealthKit authorization failed: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error, error.localizedDescription)
            } else {
                os_log("HealthKit authorization granted", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info)
            }
        }
    }
    
    // MARK: - Save Workout to HealthKit
    
    func saveWorkoutToHealthKit(workoutData: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard let name = workoutData["name"] as? String,
              let startTime = workoutData["startTime"] as? Int64,
              let endTime = workoutData["endTime"] as? Int64,
              let duration = workoutData["duration"] as? Int else {
            os_log("Invalid workout data for HealthKit", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error)
            completion(false, nil)
            return
        }
        
        let startDate = Date(timeIntervalSince1970: TimeInterval(startTime / 1000))
        let endDate = Date(timeIntervalSince1970: TimeInterval(endTime / 1000))
        
        // Determine workout type based on exercises
        let exercises = workoutData["exercises"] as? [[String: Any]] ?? []
        let isCardio = exercises.contains { ($0["muscle"] as? String)?.lowercased().contains("cardio") == true }
        let workoutType = isCardio ? cardioWorkout : traditionalStrengthWorkout
        
        // Add metadata
        var metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "LosMooScles",
            "WorkoutType": name
        ]
        
        if let rpe = workoutData["rpe"] as? Int {
            metadata["RPE"] = rpe
        }
        
        if let notes = workoutData["notes"] as? String {
            metadata["Notes"] = notes
        }
        
        if let totalSets = workoutData["totalSets"] as? Int {
            metadata["TotalSets"] = totalSets
        }
        
        if let completedSets = workoutData["completedSets"] as? Int {
            metadata["CompletedSets"] = completedSets
        }
        
        if let totalWeightVolume = workoutData["totalWeightVolume"] as? Double {
            metadata["TotalWeightVolume"] = totalWeightVolume
        }
        
        // Create workout with metadata
        let workout = HKWorkout(
            activityType: workoutType,
            start: startDate,
            end: endDate,
            duration: TimeInterval(duration),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata.isEmpty ? nil : metadata
        )
        
        // Save to HealthKit
        healthStore.save(workout) { success, error in
            if let error = error {
                os_log("Failed to save workout to HealthKit: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error, error.localizedDescription)
                completion(false, error)
            } else {
                os_log("Saved workout '%s' to HealthKit", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info, name)
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Query Workouts from HealthKit
    
    func queryRecentWorkouts(limit: Int = 10, completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            let workouts = samples as? [HKWorkout]
            completion(workouts, error)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Delete Workout from HealthKit
    
    func deleteWorkoutFromHealthKit(workout: HKWorkout, completion: @escaping (Bool, Error?) -> Void) {
        healthStore.delete(workout) { success, error in
            if let error = error {
                os_log("Failed to delete workout from HealthKit: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error, error.localizedDescription)
            } else {
                os_log("Deleted workout from HealthKit", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info)
            }
            completion(success, error)
        }
    }
    
    // MARK: - Add Workout Samples (Optional)
    
    func addWorkoutSamples(workout: HKWorkout, samples: [HKSample], completion: @escaping (Bool, Error?) -> Void) {
        healthStore.add(samples, to: workout) { success, error in
            if let error = error {
                os_log("Failed to add samples to workout: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error, error.localizedDescription)
            }
            completion(success, error)
        }
    }
    
    // MARK: - Check HealthKit Availability
    
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Backup All Local Workouts to HealthKit
    
    func backupLocalWorkoutsToHealthKit(completion: @escaping (Int, Int) -> Void) {
        let localWorkoutManager = WatchLocalWorkoutManager.shared
        let pendingWorkouts = localWorkoutManager.getPendingSyncWorkouts()
        
        var savedCount = 0
        var failedCount = 0
        
        guard !pendingWorkouts.isEmpty else {
            completion(0, 0)
            return
        }
        
        let group = DispatchGroup()
        
        for item in pendingWorkouts {
            group.enter()
            
            // Convert WatchActiveWorkoutState to workout dictionary
            let workoutDict = localWorkoutManager.completeLocalWorkout(
                activeWorkout: item.workoutData,
                rpe: 8,
                notes: "Backup from watch"
            )
            
            saveWorkoutToHealthKit(workoutData: workoutDict) { success, error in
                if success {
                    savedCount += 1
                    localWorkoutManager.markAsSynced(workoutId: item.id)
                } else {
                    failedCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            localWorkoutManager.clearSyncedWorkouts()
            completion(savedCount, failedCount)
        }
    }
}
