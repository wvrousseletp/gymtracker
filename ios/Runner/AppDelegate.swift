import UIKit
import Flutter
import WatchConnectivity

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  
  private var session: WCSession?
  private var methodChannel: FlutterMethodChannel?

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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let session = session else {
      result(FlutterError(code: "UNAVAILABLE", message: "Watch session not initialized", details: nil))
      return
    }

    switch call.method {
    case "updateRoutines":
      if let json = call.arguments as? String {
        session.transferUserInfo(["action": "updateRoutines", "routines": json])
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for routines", details: nil))
      }
    case "updateLibrary":
      if let json = call.arguments as? String {
        session.transferUserInfo(["action": "updateLibrary", "library": json])
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for library", details: nil))
      }
    case "updateActiveWorkout":
      if let json = call.arguments as? String {
        session.transferUserInfo(["action": "updateActiveWorkout", "activeWorkout": json])
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected JSON string for active workout", details: nil))
      }
    case "clearActiveWorkout":
      session.transferUserInfo(["action": "clearActiveWorkout"])
      result(nil)
    case "workoutFinished", "workoutCancelled":
      session.transferUserInfo(["action": call.method])
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
          self.methodChannel?.invokeMethod("toggleSet", arguments: [
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex
          ])
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
      default:
        break
      }
    }
  }
}
