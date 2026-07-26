import Foundation
import HealthKit
import Combine
import os.log

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    let healthStore = HKHealthStore()
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var basalCalories: Double = 0
    @Published var stepCount: Int = 0
    @Published var distance: Double = 0
    @Published var heartRateVariability: Double = 0
    @Published var bloodOxygen: Double = 0
    @Published var altitude: Double = 0
    @Published var workoutSessionState: HKWorkoutSessionState = .notStarted
    
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    private var lastHealthSync = Date.distantPast
    var healthSyncInterval: TimeInterval = 5
    var isLaunchedByiOS = false
    
    private override init() {
        super.init()
    }
    
    func recoverOrphanedSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.recoverActiveWorkoutSession { [weak self] (session, error) in
            guard let self = self else { return }
            if let activeSession = session {
                DispatchQueue.main.async {
                    if self.isLaunchedByiOS {
                        print("Ignoring recovered session because app was launched by iOS.")
                        return
                    }
                    if self.session != nil && self.session !== activeSession {
                        print("Ignoring recovered session because we already have another active session.")
                        return
                    }
                    if self.session === activeSession {
                        return
                    }
                    
                    self.session = activeSession
                    self.builder = activeSession.associatedWorkoutBuilder()
                    self.session?.delegate = self
                    self.builder?.delegate = self
                    
                    // Allow time for WatchConnectivityManager to load cache and determine if this is a legitimate ongoing workout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if WatchConnectivityManager.shared.activeWorkout == nil && !self.isLaunchedByiOS {
                            print("Orphaned workout session detected! Force ending it.")
                            self.endWorkout(save: false)
                        } else {
                            self.workoutSessionState = activeSession.state
                        }
                    }
                }
            }
        }
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                os_log("HealthKit authorized successfully", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info)
            } else if let error = error {
                os_log("HealthKit authorization failed: %{public}@", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .error, error.localizedDescription)
            }
        }
    }
    
    func startWorkout(exercises: [WatchActiveExercise]? = nil, configuration providedConfiguration: HKWorkoutConfiguration? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Ensure no existing session is active
        if session != nil {
            return
        }
        
        let configuration: HKWorkoutConfiguration
        if let provided = providedConfiguration {
            configuration = provided
        } else {
            configuration = HKWorkoutConfiguration()
            // Auto-detect workout type based on exercises
            let hasCardio = exercises?.contains(where: { $0.muscle.lowercased().contains("cardio") }) ?? false
            configuration.activityType = hasCardio ? .other : .traditionalStrengthTraining
            configuration.locationType = .indoor
        }
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
            return
        }
        
        session?.delegate = self
        builder?.delegate = self
        
        let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        dataSource.enableCollection(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!, predicate: nil)
        dataSource.enableCollection(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, predicate: nil)
        builder?.dataSource = dataSource
        
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { success, error in
            if success {
                print("Workout collection started successfully")
            } else if let error = error {
                print("Failed to begin collection: \(error.localizedDescription)")
            }
        }
    }
    
    func pauseWorkout() {
        session?.pause()
    }
    
    func resumeWorkout() {
        session?.resume()
    }
    
    func endWorkout(save: Bool) {
        guard let session = session else { return }
        session.end()
        
        let endDate = Date()
        builder?.endCollection(withEnd: endDate) { [weak self] success, error in
            guard let self = self else { return }
            if !success {
                print("Failed to end collection: \(error?.localizedDescription ?? "unknown error")")
                self.resetWorkout()
                return
            }
            
            if save {
                self.builder?.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Failed to finish workout: \(error.localizedDescription)")
                        } else {
                            print("Workout finished and saved successfully!")
                        }
                        self.resetWorkout()
                    }
                }
            } else {
                self.builder?.discardWorkout()
                DispatchQueue.main.async {
                    print("Workout discarded")
                    self.resetWorkout()
                }
            }
        }
    }
    
    private func resetWorkout() {
        session = nil
        builder = nil
        DispatchQueue.main.async {
            self.heartRate = 0
            self.activeCalories = 0
            self.basalCalories = 0
            self.stepCount = 0
            self.distance = 0
            self.heartRateVariability = 0
            self.bloodOxygen = 0
            self.altitude = 0
            self.workoutSessionState = .notStarted
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.workoutSessionState = toState
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Collect events
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        for type in types {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            DispatchQueue.main.async {
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                        let unit = HKUnit(from: "count/min")
                        if let quantity = statistics.mostRecentQuantity() {
                            self.heartRate = quantity.doubleValue(for: unit)
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                        let unit = HKUnit.kilocalorie()
                        if let quantity = statistics.sumQuantity() {
                            self.activeCalories = quantity.doubleValue(for: unit)
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
                        let unit = HKUnit.kilocalorie()
                        if let quantity = statistics.sumQuantity() {
                            self.basalCalories = quantity.doubleValue(for: unit)
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .stepCount) {
                        let unit = HKUnit.count()
                        if let quantity = statistics.sumQuantity() {
                            self.stepCount = Int(quantity.doubleValue(for: unit))
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                        let unit = HKUnit.meter()
                        if let quantity = statistics.sumQuantity() {
                            self.distance = quantity.doubleValue(for: unit)
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                        let unit = HKUnit.secondUnit(with: .milli)
                        if let quantity = statistics.mostRecentQuantity() {
                            self.heartRateVariability = quantity.doubleValue(for: unit)
                        }
                    } else if quantityType == HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
                        let unit = HKUnit.percent()
                        if let quantity = statistics.mostRecentQuantity() {
                            self.bloodOxygen = quantity.doubleValue(for: unit)
                        }
                    }
                }
                
                // Envia métricas em tempo real para o iPhone (debounced)
                let now = Date()
                if now.timeIntervalSince(self.lastHealthSync) >= self.healthSyncInterval {
                    self.lastHealthSync = now
                    WatchConnectivityManager.shared.sendHealthMetrics(
                        heartRate: self.heartRate,
                        calories: self.activeCalories
                    )
                }
            }
        }
    }
}
