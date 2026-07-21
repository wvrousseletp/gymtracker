import AppIntents
import ActivityKit
import WidgetKit
import Foundation

@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
struct CompleteSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Concluir Série"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        guard let jsonStr = sharedDefaults?.string(forKey: "activeWorkoutJson"),
              let data = jsonStr.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return .result()
        }
        
        var currentIndex = json["currentExerciseIndex"] as? Int ?? 0
        guard var exercises = json["exercises"] as? [[String: Any]],
              currentIndex < exercises.count else {
            return .result()
        }
        
        var exercise = exercises[currentIndex]
        guard var setsState = exercise["setsState"] as? [Bool] else {
            return .result()
        }
        
        // Find first incomplete set
        if let firstIncompleteIndex = setsState.firstIndex(of: false) {
            setsState[firstIncompleteIndex] = true
            exercise["setsState"] = setsState
            exercises[currentIndex] = exercise
            json["exercises"] = exercises
            
            // Check if this exercise is complete
            let isExerciseComplete = !setsState.contains(false)
            let restSeconds = exercise["rest"] as? Int ?? 60
            
            if !isExerciseComplete {
                // Start rest timer for next set
                let endTimeMs = Double(Date().timeIntervalSince1970 * 1000) + Double(restSeconds * 1000)
                let restTimer: [String: Any] = [
                    "endTime": endTimeMs,
                    "totalSeconds": restSeconds,
                    "nextExerciseName": exercise["name"] as? String ?? "Exercício",
                    "nextSetNum": firstIncompleteIndex + 2,
                    "isPrep": false
                ]
                json["restTimer"] = restTimer
            } else {
                // Exercise complete. Go to next exercise if available
                if currentIndex < exercises.count - 1 {
                    let nextIndex = currentIndex + 1
                    json["currentExerciseIndex"] = nextIndex
                    let nextExercise = exercises[nextIndex]
                    
                    // Start rest timer transition to next exercise
                    let endTimeMs = Double(Date().timeIntervalSince1970 * 1000) + Double(restSeconds * 1000)
                    let restTimer: [String: Any] = [
                        "endTime": endTimeMs,
                        "totalSeconds": restSeconds,
                        "nextExerciseName": nextExercise["name"] as? String ?? "Exercício",
                        "nextSetNum": 1,
                        "isPrep": false
                    ]
                    json["restTimer"] = restTimer
                } else {
                    // Workout finished!
                    json["restTimer"] = NSNull()
                    // Mark as finished pending
                    sharedDefaults?.set(true, forKey: "finishWorkoutPending")
                }
            }
            
            if let updatedData = try? JSONSerialization.data(withJSONObject: json),
               let updatedStr = String(data: updatedData, encoding: .utf8) {
                sharedDefaults?.set(updatedStr, forKey: "activeWorkoutJson")
            }
        }
        
        // Update the Live Activity immediately
        updateLiveActivityFromUserDefaults()
        
        return .result()
    }
}

@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
struct SkipRestIntent: AppIntent {
    static var title: LocalizedStringResource = "Pular Descanso"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        guard let jsonStr = sharedDefaults?.string(forKey: "activeWorkoutJson"),
              let data = jsonStr.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return .result()
        }
        
        json["restTimer"] = NSNull()
        
        if let updatedData = try? JSONSerialization.data(withJSONObject: json),
           let updatedStr = String(data: updatedData, encoding: .utf8) {
            sharedDefaults?.set(updatedStr, forKey: "activeWorkoutJson")
        }
        
        updateLiveActivityFromUserDefaults()
        return .result()
    }
}

@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
struct TogglePauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Pausar/Retomar Treino"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        guard let jsonStr = sharedDefaults?.string(forKey: "activeWorkoutJson"),
              let data = jsonStr.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return .result()
        }
        
        let currentPaused = json["paused"] as? Bool ?? false
        json["paused"] = !currentPaused
        
        if let updatedData = try? JSONSerialization.data(withJSONObject: json),
           let updatedStr = String(data: updatedData, encoding: .utf8) {
            sharedDefaults?.set(updatedStr, forKey: "activeWorkoutJson")
        }
        
        updateLiveActivityFromUserDefaults()
        return .result()
    }
}

@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
struct FinishWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Finalizar Treino"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        sharedDefaults?.set(true, forKey: "finishWorkoutPending")
        
        // Stop all active Live Activities
        for activity in Activity<WorkoutWidgetAttributes>.activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        
        return .result()
    }
}

@available(iOS 16.1, *)
func updateLiveActivityFromUserDefaults() {
    let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
    guard let jsonStr = sharedDefaults?.string(forKey: "activeWorkoutJson"),
          let data = jsonStr.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return
    }
    
    let isPaused = json["paused"] as? Bool ?? false
    let elapsedSeconds = json["elapsedSeconds"] as? Int ?? 0
    
    var exerciseName = "Nenhum exercício ativo"
    var setInfo = ""
    var restEndDate: Date? = nil
    var restTotalSeconds = 0
    var restIsPrep = false
    
    var completedSets = 0
    var totalSets = 0
    
    var isCardio = false
    
    if let exercises = json["exercises"] as? [[String: Any]],
       let currentIndex = json["currentExerciseIndex"] as? Int,
       currentIndex < exercises.count {
        let currentExercise = exercises[currentIndex]
        exerciseName = currentExercise["name"] as? String ?? "Exercício"
        isCardio = currentExercise["isCardio"] as? Bool ?? false
        
        let sets = currentExercise["sets"] as? Int ?? 0
        totalSets = sets
        var completedCount = 0
        if let setsState = currentExercise["setsState"] as? [Bool] {
            completedCount = setsState.filter { $0 }.count
        }
        completedSets = completedCount
        
        let weight = currentExercise["weight"] as? Double ?? 0.0
        let reps = currentExercise["reps"] as? Int ?? 0
        
        if weight > 0 {
            setInfo = "Série \(completedCount + 1) de \(sets) • \(weight)kg x \(reps) reps"
        } else {
            setInfo = "Série \(completedCount + 1) de \(sets) • \(reps) reps"
        }
    }
    
    if let restTimer = json["restTimer"] as? [String: Any],
       let endTimeMs = restTimer["endTime"] as? Double {
        restEndDate = Date(timeIntervalSince1970: endTimeMs / 1000.0)
        restTotalSeconds = restTimer["totalSeconds"] as? Int ?? 0
        restIsPrep = restTimer["isPrep"] as? Bool ?? false
    }
    
    let contentState = WorkoutWidgetAttributes.ContentState(
        exerciseName: exerciseName,
        currentSetInfo: setInfo,
        isPaused: isPaused,
        elapsedSeconds: elapsedSeconds,
        restTimerEndDate: restEndDate,
        restTimerTotalSeconds: restTotalSeconds,
        restIsPrep: restIsPrep,
        completedSets: completedSets,
        totalSets: totalSets,
        isCardio: isCardio
    )
    
    Task {
        for activity in Activity<WorkoutWidgetAttributes>.activities {
            await activity.update(using: contentState)
        }
    }
}
