import UIKit
import Flutter
import WatchConnectivity

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  
  private var session: WCSession?
  private var methodChannel: FlutterMethodChannel?
  private var applicationContextCache: [String: Any] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "com.vicente.losmooscles/watch",
                                              binaryMessenger: controller.binaryMessenger)
    
    methodChannel?.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      self?.handleFlutterCall(call, result: result)
    })

    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
      applicationContextCache = session?.applicationContext ?? [:]
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for active workout", details: nil))
      }
    case "clearActiveWorkout", "workoutFinished", "workoutCancelled":
      sendToWatch("activeWorkout", json: nil, clearActive: true)
      result(nil)
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
      case "togglePause":
        if let paused = data["paused"] as? Bool {
          self.methodChannel?.invokeMethod("togglePause", arguments: paused)
        }
      case "requestSync":
        self.methodChannel?.invokeMethod("sessionActivated", arguments: nil)
      default:
        break
      }
    }
  }
}
