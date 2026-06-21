import UIKit
import Flutter
import WatchConnectivity
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  
  private var session: WCSession?
  private var methodChannel: FlutterMethodChannel?
  private var applicationContextCache: [String: Any] = [:]
  private var workoutActivity: Any? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: "com.vicente.losmooscles/watch",
                                                binaryMessenger: controller.binaryMessenger)
      
      methodChannel?.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        self?.handleFlutterCall(call, result: result)
      })
    }

    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
      applicationContextCache = session?.applicationContext ?? [:]
    }

    return result
  }

  private func sendToWatch(_ key: String, json: String?, clearActive: Bool = false) {
    guard let session = session else { return }
    
    if clearActive {
      applicationContextCache["activeWorkout"] = nil
      applicationContextCache["clearActiveWorkout"] = true
    } else if let keyVal = json {
      applicationContextCache[key] = keyVal
      if key == "activeWorkout" {
        applicationContextCache["clearActiveWorkout"] = nil
      }
    }
    
    // 1. Update application context for persistence
    do {
      try session.updateApplicationContext(applicationContextCache)
    } catch {
      print("[AppDelegate] Error updating application context for \(key): \(error.localizedDescription)")
    }
    
    // 2. Real-time message if reachable
    if session.isReachable {
      var msg: [String: Any] = [:]
      if clearActive {
        msg["action"] = "clearActiveWorkout"
        msg["clearActiveWorkout"] = true
      } else if let keyVal = json {
        let actionName = "update" + key.prefix(1).uppercased() + key.dropFirst()
        msg["action"] = actionName
        msg[key] = keyVal
      }
      session.sendMessage(msg, replyHandler: nil) { [weak self] error in
        print("[AppDelegate] Error sending real-time message for \(key): \(error.localizedDescription)")
        self?.session?.transferUserInfo(msg)
      }
    } else {
      // Fallback to transferUserInfo for background/reliability
      var msg: [String: Any] = [:]
      if clearActive {
        msg["action"] = "clearActiveWorkout"
        msg["clearActiveWorkout"] = true
      } else if let keyVal = json {
        let actionName = "update" + key.prefix(1).uppercased() + key.dropFirst()
        msg["action"] = actionName
        msg[key] = keyVal
      }
      session.transferUserInfo(msg)
    }
  }

  private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let session = session else {
      result(FlutterError(code: "UNAVAILABLE", message: "Watch session not initialized", details: nil))
      return
    }

    switch call.method {
    case "updateRoutines":
      if let json = call.arguments as? String {
        sendToWatch("routines", json: json)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for routines", details: nil))
      }
    case "updateLibrary":
      if let json = call.arguments as? String {
        sendToWatch("library", json: json)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for library", details: nil))
      }
    case "updateActiveWorkout":
      if let json = call.arguments as? String {
        sendToWatch("activeWorkout", json: json)
        self.updateLiveActivity(workoutJson: json)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for active workout", details: nil))
      }
    case "updatePlanner":
      if let json = call.arguments as? String {
        sendToWatch("planner", json: json)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for planner", details: nil))
      }
    case "clearActiveWorkout", "workoutFinished", "workoutCancelled":
      sendToWatch("activeWorkout", json: nil, clearActive: true)
      self.stopLiveActivity()
      result(nil)
    case "updateWidgetData":
      if let args = call.arguments as? [String: Any] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        if let todayRoutineName = args["todayRoutineName"] as? String {
          sharedDefaults?.set(todayRoutineName, forKey: "todayRoutineName")
        }
        if let todayRoutineExerciseCount = args["todayRoutineExerciseCount"] as? Int {
          sharedDefaults?.set(todayRoutineExerciseCount, forKey: "todayRoutineExerciseCount")
        }
        if let todayRoutineExercises = args["todayRoutineExercises"] as? [String] {
          sharedDefaults?.set(todayRoutineExercises, forKey: "todayRoutineExercises")
        }
        if let waterIntakeCurrent = args["waterIntakeCurrent"] as? Int {
          sharedDefaults?.set(waterIntakeCurrent, forKey: "waterIntakeCurrent")
        }
        if let waterIntakeTarget = args["waterIntakeTarget"] as? Int {
          sharedDefaults?.set(waterIntakeTarget, forKey: "waterIntakeTarget")
        }
        sharedDefaults?.synchronize()
        
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected dictionary for widget data", details: nil))
      }

    case "prCelebration":
      // Forward a PR celebration to the Apple Watch
      if let exerciseNames = call.arguments as? [String] {
        let msg: [String: Any] = [
          "action": "prCelebration",
          "exerciseNames": exerciseNames
        ]
        if session.isReachable {
          session.sendMessage(msg, replyHandler: nil) { [weak self] error in
            print("[AppDelegate] Error sending prCelebration: \(error.localizedDescription)")
            self?.session?.transferUserInfo(msg)
          }
        } else {
          session.transferUserInfo(msg)
        }
        result(nil)
      } else {
        result(nil)
      }

    case "updateStreak":
      // Forward streak update to the Apple Watch
      if let streakArgs = call.arguments as? [String: Any],
         let streakData = try? JSONSerialization.data(withJSONObject: streakArgs),
         let streakJson = String(data: streakData, encoding: .utf8) {
        // Persist in application context for offline access
        applicationContextCache["streak"] = streakJson
        do {
          try session.updateApplicationContext(applicationContextCache)
        } catch {
          print("[AppDelegate] Error updating application context for streak: \(error.localizedDescription)")
        }
        // Also send real-time if reachable
        let msg: [String: Any] = ["action": "updateStreak", "streak": streakJson]
        if session.isReachable {
          session.sendMessage(msg, replyHandler: nil) { [weak self] error in
            print("[AppDelegate] Error sending streak: \(error.localizedDescription)")
            self?.session?.transferUserInfo(msg)
          }
        } else {
          session.transferUserInfo(msg)
        }
        result(nil)
      } else {
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - WCSessionDelegate Methods

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let error = error {
      print("WCSession activation failed with error: \(error.localizedDescription)")
    } else {
      print("WCSession activated successfully with state: \(activationState.rawValue)")
      if activationState == .activated {
        DispatchQueue.main.async { [weak self] in
          self?.methodChannel?.invokeMethod("sessionActivated", arguments: nil)
        }
      }
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    handleIncomingWatchData(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
    handleIncomingWatchData(userInfo)
  }

  private func handleIncomingWatchData(_ data: [String : Any]) {
    guard let action = data["action"] as? String else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      switch action {
      case "startWorkout":
        if let routineId = data["routineId"] as? String {
          self.methodChannel?.invokeMethod("startWorkout", arguments: routineId)
        }
      case "toggleSet":
        if let exerciseIndex = data["exerciseIndex"] as? Int,
           let setIndex = data["setIndex"] as? Int {
          var args: [String: Any] = [
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "isDone": data["isDone"] as? Bool ?? true,
            "isFailure": data["isFailure"] as? Bool ?? false
          ]
          if let failureRep = data["failureRep"] as? Int {
            args["failureRep"] = failureRep
          }
          if let distance = data["distance"] as? Double {
            args["distance"] = distance
          }
          if let duration = data["duration"] as? Int {
            args["duration"] = duration
          }
          self.methodChannel?.invokeMethod("toggleSet", arguments: args)
        }
      case "updateCardio":
        if let exerciseIndex = data["exerciseIndex"] as? Int,
           let setIndex = data["setIndex"] as? Int,
           let distance = data["distance"] as? Double,
           let duration = data["duration"] as? Int {
          self.methodChannel?.invokeMethod("updateCardio", arguments: [
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "distance": distance,
            "duration": duration
          ])
        }
      case "updateFailure":
        if let exerciseIndex = data["exerciseIndex"] as? Int,
           let setIndex = data["setIndex"] as? Int,
           let isFailure = data["isFailure"] as? Bool {
          var args: [String: Any] = [
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "isFailure": isFailure
          ]
          if let failureRep = data["failureRep"] as? Int {
            args["failureRep"] = failureRep
          }
          self.methodChannel?.invokeMethod("updateFailure", arguments: args)
        }
      case "skipRest":
        self.methodChannel?.invokeMethod("skipRest", arguments: nil)
      case "updateExerciseWeightReps":
        if let exerciseIndex = data["exerciseIndex"] as? Int,
           let weight = data["weight"] as? Double,
           let reps = data["reps"] as? Int {
          self.methodChannel?.invokeMethod("updateExerciseWeightReps", arguments: [
            "exerciseIndex": exerciseIndex,
            "weight": weight,
            "reps": reps
          ])
        }
      case "startSingleExercise":
        if let exerciseId = data["exerciseId"] as? String {
          self.methodChannel?.invokeMethod("startSingleExercise", arguments: exerciseId)
        }
      case "completeWorkout":
        self.methodChannel?.invokeMethod("completeWorkout", arguments: nil)
      case "cancelWorkout":
        self.methodChannel?.invokeMethod("cancelWorkout", arguments: nil)
      case "postponeWorkout":
        self.methodChannel?.invokeMethod("postponeWorkout", arguments: nil)
      case "resumeWorkout":
        self.methodChannel?.invokeMethod("resumeWorkout", arguments: nil)
      case "togglePause":
        if let paused = data["paused"] as? Bool {
          self.methodChannel?.invokeMethod("togglePause", arguments: paused)
        }
      case "requestSync":
        self.methodChannel?.invokeMethod("sessionActivated", arguments: nil)
      case "syncOfflineWorkout":
        if let workoutData = data["workoutData"] as? [String: Any] {
          self.methodChannel?.invokeMethod("syncOfflineWorkout", arguments: workoutData)
        }
      case "changeExercise":
        if let exerciseIndex = data["exerciseIndex"] as? Int {
          self.methodChannel?.invokeMethod("changeExercise", arguments: exerciseIndex)
        }
      default:
        break
      }
    }
  }

  // MARK: - Live Activity Management
  
  private func updateLiveActivity(workoutJson: String) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    
    guard let data = workoutJson.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
        return
    }
    
    let workoutName = json["name"] as? String ?? "Treino"
    let isPaused = json["paused"] as? Bool ?? false
    let elapsedSeconds = json["elapsedSeconds"] as? Int ?? 0
    let postponed = json["postponed"] as? Bool ?? false
    
    var exerciseName = "Nenhum exercício ativo"
    var setInfo = ""
    
    if let exercises = json["exercises"] as? [[String: Any]],
       let currentIndex = json["currentExerciseIndex"] as? Int,
       currentIndex < exercises.count {
        let currentExercise = exercises[currentIndex]
        exerciseName = currentExercise["name"] as? String ?? "Exercício"
        
        let sets = currentExercise["sets"] as? Int ?? 0
        
        var completedCount = 0
        if let setsState = currentExercise["setsState"] as? [Bool] {
            completedCount = setsState.filter { $0 }.count
        }
        
        let weight = currentExercise["weight"] as? Double ?? 0.0
        let reps = currentExercise["reps"] as? Int ?? 0
        
        if weight > 0 {
            setInfo = "Série \(completedCount + 1) de \(sets) • \(weight)kg x \(reps) reps"
        } else {
            setInfo = "Série \(completedCount + 1) de \(sets) • \(reps) reps"
        }
    }
    
    if postponed {
        stopLiveActivity()
        return
    }
    
    let contentState = WorkoutWidgetAttributes.ContentState(
        exerciseName: exerciseName,
        currentSetInfo: setInfo,
        isPaused: isPaused,
        elapsedSeconds: elapsedSeconds
    )
    
    if let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> {
        Task {
            await activity.update(using: contentState)
        }
    } else {
        let attributes = WorkoutWidgetAttributes(workoutName: workoutName)
        do {
            let activity = try Activity<WorkoutWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            workoutActivity = activity
            print("Successfully started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    #endif
  }

  private func stopLiveActivity() {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> else { return }
    
    Task {
        await activity.end(dismissalPolicy: .immediate)
        workoutActivity = nil
        print("Successfully stopped Live Activity")
    }
    #endif
  }
}
