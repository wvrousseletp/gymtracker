import UIKit
import Flutter
import WatchConnectivity
import UserNotifications
import HealthKit
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
  private let healthStore = HKHealthStore()

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

  // MARK: - Background Execution

  private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  private var workoutTimerBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  // Rest Timer State for Live Activity Sync
  private var currentRestEndDate: Date? = nil
  private var currentRestTotalSeconds: Int = 0
  private var currentRestIsPrep: Bool = false

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Start a background task to keep the workout timer running
    workoutTimerBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "WorkoutTimer") { [weak self] in
      // Expiration handler - called when system is about to terminate
      self?.endBackgroundTasks()
    }

    // Notify Flutter that app is entering background
    methodChannel?.invokeMethod("appDidEnterBackground", arguments: nil)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    // End background task when returning to foreground
    endBackgroundTasks()

    // Notify Flutter that app is entering foreground
    methodChannel?.invokeMethod("appWillEnterForeground", arguments: nil)
  }

  private func endBackgroundTasks() {
    if workoutTimerBackgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(workoutTimerBackgroundTask)
      workoutTimerBackgroundTask = .invalid
    }
    if backgroundTaskID != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskID)
      backgroundTaskID = .invalid
    }
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

  private func sendWaterToWatch(current: Int, target: Int, date: String) {
    guard let session = session else { return }
    
    applicationContextCache["waterIntakeCurrent"] = current
    applicationContextCache["waterIntakeTarget"] = target
    applicationContextCache["waterIntakeDate"] = date
    
    do {
      try session.updateApplicationContext(applicationContextCache)
    } catch {
      print("[AppDelegate] Error updating application context for water: \(error.localizedDescription)")
    }
    
    let msg: [String: Any] = [
      "action": "updateWater",
      "waterIntakeCurrent": current,
      "waterIntakeTarget": target,
      "waterIntakeDate": date
    ]
    
    if session.isReachable {
      session.sendMessage(msg, replyHandler: nil) { error in
        print("[AppDelegate] Error sending real-time water: \(error.localizedDescription)")
        session.transferUserInfo(msg)
      }
    } else {
      session.transferUserInfo(msg)
    }
  }

  private func launchWatchAppWithRetry(attempt: Int, maxAttempts: Int) {
    print("[AppDelegate] Attempting to launch watch app - Attempt \(attempt + 1)/\(maxAttempts)")
    
    guard HKHealthStore.isHealthDataAvailable() else {
      print("[AppDelegate] HealthKit is not available on this device")
      return
    }
    
    print("[AppDelegate] HealthKit is available, creating workout configuration")
    
    let configuration = HKWorkoutConfiguration()
    if let json = UserDefaults(suiteName: "group.com.vicente.losmooscles")?.string(forKey: "activeWorkoutJson"),
       json.lowercased().contains("cardio") {
      configuration.activityType = .running
    } else {
      configuration.activityType = .traditionalStrengthTraining
    }
    configuration.locationType = .indoor
    
    DispatchQueue.main.async { [weak self] in
      print("[AppDelegate] Calling healthStore.startWatchApp with configuration on main thread")
      self?.healthStore.startWatchApp(with: configuration) { success, error in
        if let error = error {
          print("[AppDelegate] Watch app launch attempt \(attempt + 1) failed: \(error.localizedDescription)")
          print("[AppDelegate] Error details: \(error)")
          
          if attempt < maxAttempts - 1 {
            let delay = TimeInterval(pow(2.0, Double(attempt))) // 1s, 2s, 4s
            print("[AppDelegate] Scheduling retry in \(delay) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
              self?.launchWatchAppWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
          } else {
            print("[AppDelegate] All watch app launch attempts failed. Workout data sent via WCSession instead.")
          }
        } else if success {
          print("[AppDelegate] Watch app launched successfully on attempt \(attempt + 1)")
        } else {
          print("[AppDelegate] Watch app launch returned success=false on attempt \(attempt + 1)")
        }
      }
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
    case "prepareWatchApp":
      print("[AppDelegate] prepareWatchApp called")
      if HKHealthStore.isHealthDataAvailable() {
          self.launchWatchAppWithRetry(attempt: 0, maxAttempts: 3)
      }
      result(nil)
    case "updateActiveWorkout":
      print("[AppDelegate] updateActiveWorkout called")
      if let json = call.arguments as? String {
        print("[AppDelegate] Sending active workout to watch")
        sendToWatch("activeWorkout", json: json)
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        sharedDefaults?.set(json, forKey: "activeWorkoutJson")
        sharedDefaults?.synchronize()
        self.updateLiveActivity(workoutJson: json)
        
        // Enhanced watch app launch with retry mechanism
        print("[AppDelegate] WCSession isReachable: \(session.isReachable)")
        print("[AppDelegate] WCSession activationState: \(session.activationState.rawValue)")
        
        if HKHealthStore.isHealthDataAvailable() {
            print("[AppDelegate] Attempting to launch watch app with retry mechanism")
            self.launchWatchAppWithRetry(attempt: 0, maxAttempts: 3)
        } else {
            print("[AppDelegate] HealthKit is not available, cannot launch watch app")
        }
        
        result(nil)
      } else {
        print("[AppDelegate] Invalid argument for updateActiveWorkout")
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
      let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
      sharedDefaults?.set(nil, forKey: "activeWorkoutJson")
      sharedDefaults?.set(nil, forKey: "finishWorkoutPending")
      sharedDefaults?.synchronize()
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
    case "syncNotificationPreferences":
      if let args = call.arguments as? [String: Any] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        if let hydrationAggressiveness = args["hydrationAggressiveness"] as? String {
          sharedDefaults?.set(hydrationAggressiveness, forKey: "hydrationAggressiveness")
        }
        if let silenceHydrationAtNight = args["silenceHydrationAtNight"] as? Bool {
          sharedDefaults?.set(silenceHydrationAtNight, forKey: "silenceHydrationAtNight")
        }
        if let restTimerMode = args["restTimerMode"] as? String {
          sharedDefaults?.set(restTimerMode, forKey: "restTimerMode")
        }
        sharedDefaults?.synchronize()
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected dictionary", details: nil))
      }
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
        if let waterIntakeDate = args["waterIntakeDate"] as? String {
          sharedDefaults?.set(waterIntakeDate, forKey: "waterIntakeDate")
        }
        sharedDefaults?.synchronize()
        
        let current = args["waterIntakeCurrent"] as? Int ?? sharedDefaults?.integer(forKey: "waterIntakeCurrent") ?? 0
        let target = args["waterIntakeTarget"] as? Int ?? sharedDefaults?.integer(forKey: "waterIntakeTarget") ?? 2000
        let date = args["waterIntakeDate"] as? String ?? sharedDefaults?.string(forKey: "waterIntakeDate") ?? ""
        self.scheduleHydrationReminders(waterIntake: current, waterGoal: target)
        
        self.sendWaterToWatch(current: current, target: target, date: date)
        
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

    case "getSharedWaterIntake":
      let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
      let current = sharedDefaults?.integer(forKey: "waterIntakeCurrent") ?? 0
      result(current)

    case "getSharedActiveWorkout":
      let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
      let workoutJson = sharedDefaults?.string(forKey: "activeWorkoutJson")
      let finishPending = sharedDefaults?.bool(forKey: "finishWorkoutPending") ?? false
      
      var response: [String: Any] = [:]
      if let workoutJson = workoutJson {
        response["workoutJson"] = workoutJson
      }
      response["finishWorkoutPending"] = finishPending
      result(response)

    case "requestHealthAuth":
      self.requestHealthAuthorization(result: result)

    case "getDailyHealthMetrics":
      self.getDailyHealthMetrics(result: result)

    case "getRecentWorkouts":
      self.getRecentWorkouts(result: result)

    case "saveWorkoutToHealthKit":
      if let args = call.arguments as? [String: Any] {
        self.saveWorkoutToHealthKit(args: args, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected dictionary with workout data", details: nil))
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
        if let workoutJson = data["workoutJson"] as? String {
          self.invokeOrQueue(method: "updateActiveWorkoutFromWatch", arguments: workoutJson)
          let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
          sharedDefaults?.set(workoutJson, forKey: "activeWorkoutJson")
          sharedDefaults?.synchronize()
          self.updateLiveActivity(workoutJson: workoutJson)
        }
      case "updateHealthMetrics":
        if let heartRate = data["heartRate"] as? Double,
           let calories = data["activeCalories"] as? Double {
          self.methodChannel?.invokeMethod("updateHealthMetrics", arguments: [
            "heartRate": Int(heartRate),
            "activeCalories": Int(calories)
          ])
        }
      case "updateWaterIntake":
        if let currentWater = data["waterIntakeMl"] as? Int {
          let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
          sharedDefaults?.set(currentWater, forKey: "waterIntakeCurrent")
          sharedDefaults?.synchronize()
          
          #if canImport(WidgetKit)
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          #endif
          
          self.methodChannel?.invokeMethod("updateWaterIntake", arguments: currentWater)
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
    
    let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
    let mode = sharedDefaults?.string(forKey: "restTimerMode") ?? "all"
    if mode == "liveActivityOnly" {
        return // Skip banner scheduling, Live Activity is handled separately
    }

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

  private func scheduleHydrationReminders(waterIntake: Int, waterGoal: Int) {
    let hydrationNotificationIds = ["hydration_reminder_1", "hydration_reminder_2", "hydration_reminder_3"]
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: hydrationNotificationIds)
    
    guard waterIntake < waterGoal else { return }
    
    let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
    let agg = sharedDefaults?.string(forKey: "hydrationAggressiveness") ?? "standard"
    if agg == "disabled" { return }
    
    var intervals: [TimeInterval] = []
    if agg == "aggressive" {
        intervals = [3600, 7200, 10800] // 1h, 2h, 3h
    } else if agg == "relaxed" {
        intervals = [14400, 28800] // 4h, 8h
    } else {
        intervals = [7200, 14400, 21600] // 2h, 4h, 6h
    }
    
    let silenceAtNight = sharedDefaults?.bool(forKey: "silenceHydrationAtNight") ?? true
    
    let messages = [
      "Que tal um gole d'água? Você bebeu \(waterIntake)ml de \(waterGoal)ml hoje. Vamos bater a meta!",
      "Lembrete de hidratação: beba um copo de água para manter o foco e energia!",
      "Não se esqueça de se hidratar hoje! Seu corpo agradece. 💪"
    ]
    
    for i in 0..<intervals.count {
      let content = UNMutableNotificationContent()
      content.title = "💧 Lembrete de Hidratação"
      content.body = messages[i]
      content.sound = UNNotificationSound.default
      
      let triggerDate = Date().addingTimeInterval(intervals[i])
      var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
      
      if silenceAtNight {
         if let hour = components.hour, (hour >= 22 || hour < 8) {
            // Push to next morning 8 AM
            if hour >= 22 {
               if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: triggerDate) {
                  let nextComponents = Calendar.current.dateComponents([.year, .month, .day], from: nextDay)
                  components.year = nextComponents.year
                  components.month = nextComponents.month
                  components.day = nextComponents.day
               }
            }
            components.hour = 8
            components.minute = 0
            components.second = 0
         }
      }
      
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let request = UNNotificationRequest(
        identifier: hydrationNotificationIds[i],
        content: content,
        trigger: trigger
      )
      UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
          print("[AppDelegate] Failed to schedule hydration notification \(i): \(error.localizedDescription)")
        }
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
    var elapsedSeconds = json["elapsedSeconds"] as? Int ?? 0
    let postponed = json["postponed"] as? Bool ?? false
    let startTime = json["startTime"] as? Double ?? 0
    
    // Correct the elapsedSeconds using the absolute startTime if it's currently running
    if !isPaused && startTime > 0 {
        let nowMs = Date().timeIntervalSince1970 * 1000
        elapsedSeconds = Int((nowMs - startTime) / 1000)
    }
    
    var exerciseName = "Exercício"
    var setInfo = ""
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
    
    var restTimerEndDate: Date? = nil
    var restTimerTotalSeconds = 0
    var restIsPrep = false
    
    if let restTimer = json["restTimer"] as? [String: Any],
       let endTimeMs = restTimer["endTime"] as? Double,
       endTimeMs > 0 {
        let totalSeconds = restTimer["totalSeconds"] as? Int ?? 0
        restIsPrep = restTimer["isPrep"] as? Bool ?? false
        let endDate = Date(timeIntervalSince1970: endTimeMs / 1000.0)
        
        if endDate > Date() {
            restTimerEndDate = endDate
            restTimerTotalSeconds = totalSeconds
        }
    }
    
    if postponed {
        stopLiveActivity()
        return
    }

    // Prefer rest timer from JSON, fallback to preserved state
    let finalRestEndDate: Date? = restTimerEndDate ?? self.currentRestEndDate
    let finalRestTotalSeconds: Int = restTimerEndDate != nil ? restTimerTotalSeconds : self.currentRestTotalSeconds
    let finalRestIsPrep: Bool = restTimerEndDate != nil ? restIsPrep : self.currentRestIsPrep

    let contentState = WorkoutWidgetAttributes.ContentState(
        exerciseName: exerciseName,
        currentSetInfo: setInfo,
        isPaused: isPaused,
        elapsedSeconds: elapsedSeconds,
        restTimerEndDate: finalRestEndDate,
        restTimerTotalSeconds: finalRestTotalSeconds,
        restIsPrep: finalRestIsPrep,
        completedSets: completedSets,
        totalSets: totalSets,
        isCardio: isCardio
    )
    
    // Also save current back so it's not lost
    self.currentRestEndDate = finalRestEndDate
    self.currentRestTotalSeconds = finalRestTotalSeconds
    self.currentRestIsPrep = finalRestIsPrep
    
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
    let endDate = Date(timeIntervalSince1970: endTimeMs / 1000.0)
    self.currentRestEndDate = endDate
    self.currentRestTotalSeconds = totalSeconds
    self.currentRestIsPrep = isPrep

    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard let activity = workoutActivity as? Activity<WorkoutWidgetAttributes> else { return }

    let current = activity.contentState
    let updated = WorkoutWidgetAttributes.ContentState(
        exerciseName: current.exerciseName,
        currentSetInfo: nextExName.isEmpty ? current.currentSetInfo : nextExName,
        isPaused: current.isPaused,
        elapsedSeconds: current.elapsedSeconds,
        restTimerEndDate: endDate,
        restTimerTotalSeconds: totalSeconds,
        restIsPrep: isPrep,
        completedSets: current.completedSets,
        totalSets: current.totalSets,
        isCardio: current.isCardio
    )
    Task {
        await activity.update(using: updated)
        print("[AppDelegate] Live Activity rest timer updated: \(endDate), isPrep=\(isPrep)")
    }
    #endif
  }

  private func clearLiveActivityRestTimer() {
    self.currentRestEndDate = nil
    self.currentRestTotalSeconds = 0
    self.currentRestIsPrep = false

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
        restIsPrep: false,
        completedSets: current.completedSets,
        totalSets: current.totalSets,
        isCardio: current.isCardio
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

  // MARK: - HealthKit Queries

  private func requestHealthAuthorization(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "UNAVAILABLE", message: "HealthKit is not available on this device", details: nil))
      return
    }
    
    guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
          let calories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
          let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(FlutterError(code: "INVALID_TYPE", message: "One or more HealthKit types are invalid", details: nil))
      return
    }
    
    let workout = HKObjectType.workoutType()
    let readTypes: Set<HKObjectType> = [steps, calories, heartRate, workout]
    let shareTypes: Set<HKSampleType> = [workout]
    
    healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(success)
        }
      }
    }
  }

  private func getDailyHealthMetrics(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "UNAVAILABLE", message: "HealthKit is not available", details: nil))
      return
    }
    
    guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
          let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
      result(FlutterError(code: "INVALID_TYPE", message: "HealthKit quantity types invalid", details: nil))
      return
    }
    
    let group = DispatchGroup()
    
    var steps: Double = 0
    var calories: Double = 0
    var heartRate: Double = 0
    
    group.enter()
    queryQuantityTypeSum(type: stepsType, unit: HKUnit.count()) { val in
      steps = val
      group.leave()
    }
    
    group.enter()
    queryQuantityTypeSum(type: caloriesType, unit: HKUnit.kilocalorie()) { val in
      calories = val
      group.leave()
    }
    
    group.enter()
    queryLatestHeartRate { val in
      heartRate = val
      group.leave()
    }
    
    group.notify(queue: .main) {
      let metrics: [String: Any] = [
        "steps": Int(steps),
        "activeCalories": Int(calories),
        "heartRate": Int(heartRate)
      ]
      result(metrics)
    }
  }

  private func getStartOfDay() -> Date {
    return Calendar.current.startOfDay(for: Date())
  }

  private func queryQuantityTypeSum(type: HKQuantityType, unit: HKUnit, completion: @escaping (Double) -> Void) {
    let now = Date()
    let startOfDay = getStartOfDay()
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
      if let error = error {
        print("[AppDelegate] HealthKit query error: \(error.localizedDescription)")
        completion(0)
        return
      }
      
      let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
      completion(sum)
    }
    healthStore.execute(query)
  }

  private func queryLatestHeartRate(completion: @escaping (Double) -> Void) {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      completion(0)
      return
    }
    
    let now = Date()
    let past24Hours = now.addingTimeInterval(-86400)
    let predicate = HKQuery.predicateForSamples(withStart: past24Hours, end: now, options: .strictEndDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    
    let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
      if let error = error {
        print("[AppDelegate] Heart rate query error: \(error.localizedDescription)")
        completion(0)
        return
      }
      
      if let sample = samples?.first as? HKQuantitySample {
        let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        completion(hr)
      } else {
        completion(0)
      }
    }
    healthStore.execute(query)
  }

  private func getRecentWorkouts(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "UNAVAILABLE", message: "HealthKit is not available", details: nil))
      return
    }
    
    let now = Date()
    let past7Days = now.addingTimeInterval(-7 * 24 * 60 * 60)
    let predicate = HKQuery.predicateForSamples(withStart: past7Days, end: now, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    
    let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { _, samples, error in
      if let error = error {
        result(FlutterError(code: "QUERY_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      
      var workoutsList: [[String: Any]] = []
      
      if let workoutSamples = samples as? [HKWorkout] {
        print("[AppDelegate] Found \(workoutSamples.count) workouts from HealthKit")
        let formatter = ISO8601DateFormatter()
        for workout in workoutSamples {
          print("[AppDelegate] Processing workout: type=\(workout.workoutActivityType.rawValue), duration=\(workout.duration), date=\(workout.startDate)")
          var activityName = "Exercício"
          switch workout.workoutActivityType {
          case .soccer: activityName = "Futebol"
          case .running: activityName = "Corrida"
          case .cycling: activityName = "Ciclismo"
          case .swimming: activityName = "Natação"
          case .walking: activityName = "Caminhada"
          case .traditionalStrengthTraining: activityName = "Musculação"
          case .functionalStrengthTraining: activityName = "Treino Funcional"
          case .crossTraining: activityName = "CrossFit"
          case .yoga: activityName = "Yoga"
          case .dance: activityName = "Dança"
          case .cardioDance: activityName = "Dança Aeróbica"
          case .hiking: activityName = "Trilha"
          case .rowing: activityName = "Remo"
          case .tennis: activityName = "Tênis"
          case .elliptical: activityName = "Elíptico"
          case .stairClimbing: activityName = "Escada"
          case .highIntensityIntervalTraining: activityName = "HIIT"
          case .flexibility: activityName = "Flexibilidade"
          case .mixedCardio: activityName = "Cardio Misto"
          case .preparationAndRecovery: activityName = "Preparação e Recuperação"
          case .wheelchairRunPace: activityName = "Cadeira de Rodas"
          case .wheelchairWalkPace: activityName = "Cadeira de Rodas"
          default:
            // Handle indoor cycling by checking raw value
            if workout.workoutActivityType.rawValue == 13 {
              activityName = "Bicicleta Ergométrica"
            } else {
              activityName = "Exercício Apple (\(workout.workoutActivityType.rawValue))"
            }
          }
          
          let durationSec = Int(workout.duration)
          let calories = Int(workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0)
          let dateStr = formatter.string(from: workout.startDate)
          let id = "healthkit-\(workout.uuid.uuidString)"
          
          var dict: [String: Any] = [
            "id": id,
            "name": activityName,
            "duration": durationSec,
            "calories": calories,
            "date": dateStr
          ]
          
          workoutsList.append(dict)
        }
      }
      
      DispatchQueue.main.async {
        result(workoutsList)
      }
    }
    healthStore.execute(query)
  }

  private func saveWorkoutToHealthKit(args: [String: Any], result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "UNAVAILABLE", message: "HealthKit is not available", details: nil))
      return
    }

    guard let name = args["name"] as? String,
          let duration = args["duration"] as? Int,
          let dateStr = args["date"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required fields", details: nil))
      return
    }

    let formatter = ISO8601DateFormatter()
    guard let startDate = formatter.date(from: dateStr) else {
      result(FlutterError(code: "INVALID_DATE", message: "Invalid date format", details: nil))
      return
    }

    let endDate = startDate.addingTimeInterval(TimeInterval(duration))

    // Map workout name to HKWorkoutActivityType
    let activityType: HKWorkoutActivityType
    let lowerName = name.lowercased()

    if lowerName.contains("musculação") || lowerName.contains("musculacao") || lowerName.contains("força") {
      activityType = .traditionalStrengthTraining
    } else if lowerName.contains("corrida") || lowerName.contains("run") {
      activityType = .running
    } else if lowerName.contains("ciclismo") || lowerName.contains("bike") || lowerName.contains("bicicleta") || lowerName.contains("ergométrica") || lowerName.contains("indoor") {
      activityType = .cycling
    } else if lowerName.contains("natação") || lowerName.contains("swim") {
      activityType = .swimming
    } else if lowerName.contains("caminhada") || lowerName.contains("walk") {
      activityType = .walking
    } else if lowerName.contains("funcional") {
      activityType = .functionalStrengthTraining
    } else if lowerName.contains("crossfit") {
      activityType = .crossTraining
    } else if lowerName.contains("yoga") {
      activityType = .yoga
    } else if lowerName.contains("hiit") {
      activityType = .highIntensityIntervalTraining
    } else if lowerName.contains("elíptico") || lowerName.contains("eliptico") {
      activityType = .elliptical
    } else {
      activityType = .other
    }

    // Create workout with basic parameters
    let workout = HKWorkout(activityType: activityType, start: startDate, end: endDate)

    healthStore.save(workout) { success, error in
      DispatchQueue.main.async {
        if let error = error {
          print("[AppDelegate] Error saving workout to HealthKit: \(error.localizedDescription)")
          result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
        } else {
          print("[AppDelegate] Successfully saved workout to HealthKit: \(name)")
          result(success)
        }
      }
    }
  }
}

