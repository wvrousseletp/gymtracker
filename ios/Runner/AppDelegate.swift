import UIKit
import Flutter
import WatchConnectivity
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  
  private var session: WCSession?
  private var methodChannel: FlutterMethodChannel? {
    didSet {
      // Deliver any actions that arrived before Flutter engine was ready
      if methodChannel != nil {
        flushPendingWatchActions()
      }
    }
  }
  private var applicationContextCache: [String: Any] = [:]
  private var workoutActivity: Any? = nil
  /// Actions from Watch that arrived before the Flutter method channel was initialised.
  private var pendingWatchActions: [[String: Any]] = []

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

    // Request notification permission for rest timer alerts
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        print("[AppDelegate] Notification permission error: \(error.localizedDescription)")
      } else {
        print("[AppDelegate] Notification permission granted: \(granted)")
      }
    }
    UNUserNotificationCenter.current().delegate = self

    return result
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if url.scheme == "losmooscles", url.host == "skipRest" {
      DispatchQueue.main.async { [weak self] in
        self?.methodChannel?.invokeMethod("skipRestTimer", arguments: nil)
      }
      return true
    }
    return super.application(app, open: url, options: options)
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
      self.clearRestTimerNotification()
      self.stopLiveActivity()
      result(nil)

    case "startRestTimer":
      if let args = call.arguments as? [String: Any],
         let endTimeMs = args["endTime"] as? Double,
         let totalSeconds = args["totalSeconds"] as? Int,
         let isPrep = args["isPrep"] as? Bool,
         let nextExName = args["nextExName"] as? String {
        self.updateLiveActivityRestTimer(
          endTimeMs: endTimeMs,
          totalSeconds: totalSeconds,
          isPrep: isPrep,
          nextExName: nextExName
        )
        self.scheduleRestTimerNotification(
          seconds: max(1, Int((endTimeMs / 1000.0) - Date().timeIntervalSince1970)),
          isPrep: isPrep,
          nextExName: nextExName
        )
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected {endTime, totalSeconds, isPrep, nextExName}", details: nil))
      }

    case "clearRestTimer":
      self.clearRestTimerNotification()
      self.clearLiveActivityRestTimer()
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

    case "ackOfflineWorkout":
      if let workoutId = call.arguments as? String {
        let msg: [String: Any] = [
          "action": "offlineWorkoutAck",
          "workoutId": workoutId
        ]
        if session.isReachable {
          session.sendMessage(msg, replyHandler: nil) { [weak self] error in
            print("[AppDelegate] Error sending offlineWorkoutAck: \(error.localizedDescription)")
            self?.session?.transferUserInfo(msg)
          }
        } else {
          session.transferUserInfo(msg)
        }
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected workoutId string", details: nil))
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
          self.invokeOrQueue(method: "startWorkout", arguments: routineId)
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
        // Stop Live Activity immediately – don't wait for Flutter roundtrip
        self.clearRestTimerNotification()
        self.stopLiveActivity()
        var completeArgs: [String: Any] = [:]
        if let rpe = data["rpe"] as? Int {
          completeArgs["rpe"] = rpe
        }
        if let notes = data["notes"] as? String {
          completeArgs["notes"] = notes
        }
        self.methodChannel?.invokeMethod(
          "completeWorkout",
          arguments: completeArgs.isEmpty ? nil : completeArgs
        )
      case "cancelWorkout":
        // Stop Live Activity immediately – don't wait for Flutter roundtrip
        self.clearRestTimerNotification()
        self.stopLiveActivity()
        self.methodChannel?.invokeMethod("cancelWorkout", arguments: nil)
      case "postponeWorkout":
        // Stop Live Activity immediately – don't wait for Flutter roundtrip
        self.clearRestTimerNotification()
        self.stopLiveActivity()
        self.methodChannel?.invokeMethod("postponeWorkout", arguments: nil)
      case "resumeWorkout":
        self.methodChannel?.invokeMethod("resumeWorkout", arguments: nil)
      case "togglePause":
        if let paused = data["paused"] as? Bool {
          self.methodChannel?.invokeMethod("togglePause", arguments: paused)
        }
      case "requestSync":
        self.invokeOrQueue(method: "sessionActivated", arguments: nil)
      case "syncOfflineWorkout":
        if let workoutData = data["workoutData"] as? [String: Any] {
          self.invokeOrQueue(method: "syncOfflineWorkout", arguments: workoutData)
        }
      case "changeExercise":
        if let exerciseIndex = data["exerciseIndex"] as? Int {
          self.methodChannel?.invokeMethod("changeExercise", arguments: exerciseIndex)
        }
      case "updateActiveWorkout":
        // Watch is pushing its current in-progress workout state (e.g. after reconnect
        // or while in offline/local mode). Forward it to Flutter so iOS can reconcile.
        if let workoutJson = data["activeWorkout"] as? String {
          self.invokeOrQueue(method: "updateActiveWorkoutFromWatch", arguments: workoutJson)
        }
      case "updateHealthMetrics":
        if let heartRate = data["heartRate"] as? Double,
           let calories = data["activeCalories"] as? Double {
          self.methodChannel?.invokeMethod("updateHealthMetrics", arguments: [
            "heartRate": Int(heartRate),
            "activeCalories": Int(calories)
          ])
        }
      default:
        break
      }
    }
  }

  // MARK: - Pending Watch Actions Queue

  /// Invoke a method on the Flutter channel, queuing it if the channel is not yet ready.
  private func invokeOrQueue(method: String, arguments: Any?) {
    if let ch = methodChannel {
      ch.invokeMethod(method, arguments: arguments)
    } else {
      pendingWatchActions.append(["method": method, "arguments": arguments as Any])
    }
  }

  /// Re-dispatch all actions that were queued while the Flutter engine was not ready.
  private func flushPendingWatchActions() {
    guard !pendingWatchActions.isEmpty, let ch = methodChannel else { return }
    let toFlush = pendingWatchActions
    pendingWatchActions = []
    print("[AppDelegate] Flushing \(toFlush.count) pending Watch action(s) to Flutter")
    for item in toFlush {
      if let method = item["method"] as? String {
        let args = item["arguments"]
        ch.invokeMethod(method, arguments: args is NSNull ? nil : args)
      }
    }
  }

  // MARK: - Rest Timer Notifications

  private let restTimerNotificationId = "com.vicente.losmooscles.restTimer"

  private func scheduleRestTimerNotification(seconds: Int, isPrep: Bool, nextExName: String) {
    // Cancel any previous rest timer notification
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerNotificationId])

    guard seconds > 0 else { return }

    let content = UNMutableNotificationContent()
    content.title = isPrep ? "✅ Hora de começar!" : "💪 Descanso concluído!"
    content.body = isPrep
      ? "Prepare-se para: \(nextExName)"
      : "Próximo: \(nextExName) — bora!"
    content.sound = UNNotificationSound.default
    // Time-sensitive so it shows even in Focus mode (entitlement already set)
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
    let request = UNNotificationRequest(
      identifier: restTimerNotificationId,
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("[AppDelegate] Failed to schedule rest timer notification: \(error.localizedDescription)")
      }
    }
  }

  private func clearRestTimerNotification() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerNotificationId])
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

    // Preserve any active rest timer state when updating workout info
    var restEndDate: Date? = nil
    var restTotalSeconds: Int = 0
    var restIsPrep: Bool = false
    if let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> {
        restEndDate = activity.contentState.restTimerEndDate
        restTotalSeconds = activity.contentState.restTimerTotalSeconds
        restIsPrep = activity.contentState.restIsPrep
    }

    let contentState = WorkoutWidgetAttributes.ContentState(
        exerciseName: exerciseName,
        currentSetInfo: setInfo,
        isPaused: isPaused,
        elapsedSeconds: elapsedSeconds,
        restTimerEndDate: restEndDate,
        restTimerTotalSeconds: restTotalSeconds,
        restIsPrep: restIsPrep
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

  private func updateLiveActivityRestTimer(endTimeMs: Double, totalSeconds: Int, isPrep: Bool, nextExName: String) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> else { return }

    let endDate = Date(timeIntervalSince1970: endTimeMs / 1000.0)
    let current = activity.contentState
    let updated = WorkoutWidgetAttributes.ContentState(
        exerciseName: current.exerciseName,
        currentSetInfo: nextExName.isEmpty ? current.currentSetInfo : nextExName,
        isPaused: current.isPaused,
        elapsedSeconds: current.elapsedSeconds,
        restTimerEndDate: endDate,
        restTimerTotalSeconds: totalSeconds,
        restIsPrep: isPrep
    )
    Task {
        await activity.update(using: updated)
        print("[AppDelegate] Live Activity rest timer updated: \(endDate), isPrep=\(isPrep)")
    }
    #endif
  }

  private func clearLiveActivityRestTimer() {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> else { return }

    let current = activity.contentState
    let updated = WorkoutWidgetAttributes.ContentState(
        exerciseName: current.exerciseName,
        currentSetInfo: current.currentSetInfo,
        isPaused: current.isPaused,
        elapsedSeconds: current.elapsedSeconds,
        restTimerEndDate: nil,
        restTimerTotalSeconds: 0,
        restIsPrep: false
    )
    Task {
        await activity.update(using: updated)
        print("[AppDelegate] Live Activity rest timer cleared")
    }
    #endif
  }

  private func stopLiveActivity() {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }

    // Collect all activities to end (de-duplicate via id)
    var activitiesToEnd: [Activity<WorkoutWidgetAttributes>] = []
    if let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> {
        activitiesToEnd.append(activity)
    }
    for activity in Activity<WorkoutWidgetAttributes>.activities {
        if !activitiesToEnd.contains(where: { $0.id == activity.id }) {
            activitiesToEnd.append(activity)
        }
    }
    workoutActivity = nil

    guard !activitiesToEnd.isEmpty else {
        print("[AppDelegate] No Live Activities to stop")
        return
    }

    // Request a background-task grace period so the async end() calls
    // complete even if the user immediately backgrounds the app.
    var bgTaskID: UIBackgroundTaskIdentifier = .invalid
    bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "StopLiveActivity") {
        // Expiry handler – called if the system is about to terminate us;
        // end the background task to avoid being killed.
        UIApplication.shared.endBackgroundTask(bgTaskID)
    }

    Task {
        await withTaskGroup(of: Void.self) { group in
            for activity in activitiesToEnd {
                group.addTask {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
        }
        print("[AppDelegate] Successfully stopped all Live Activities (\(activitiesToEnd.count))")
        UIApplication.shared.endBackgroundTask(bgTaskID)
    }
    #endif
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
  // Show notification banner even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier == "com.vicente.losmooscles.restTimer" {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  // Open the app to the workout screen when the notification is tapped
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier == "com.vicente.losmooscles.restTimer" {
      // Tell Flutter to navigate to workout tab
      DispatchQueue.main.async { [weak self] in
        self?.methodChannel?.invokeMethod("navigateToWorkout", arguments: nil)
      }
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
}

