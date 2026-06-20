import Foundation
import HealthKit
import Combine

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    let healthStore = HKHealthStore()
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var workoutSessionState: HKWorkoutSessionState = .notStarted
    
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    private override init() {
        super.init()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorized successfully")
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Ensure no existing session is active
        if session != nil {
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
            return
        }
        
        session?.delegate = self
        builder?.delegate = self
        
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
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
                    }
                }
            }
        }
    }
}
