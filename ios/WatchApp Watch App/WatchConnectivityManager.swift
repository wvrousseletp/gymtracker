import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var routines: [WatchRoutine] = []
    @Published var activeWorkout: WatchActiveWorkoutState?
    @Published var isReachable = false

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }

    private func handleIncomingData(_ data: [String : Any]) {
        guard let action = data["action"] as? String else { return }

        DispatchQueue.main.async {
            switch action {
            case "updateRoutines":
                if let jsonString = data["routines"] as? String,
                   let jsonData = jsonString.data(using: .utf8) {
                    do {
                        self.routines = try JSONDecoder().decode([WatchRoutine].self, from: jsonData)
                    } catch {
                        print("Error decoding routines: \(error)")
                    }
                }
            case "updateActiveWorkout":
                if let jsonString = data["activeWorkout"] as? String,
                   let jsonData = jsonString.data(using: .utf8) {
                    do {
                        self.activeWorkout = try JSONDecoder().decode(WatchActiveWorkoutState.self, from: jsonData)
                    } catch {
                        print("Error decoding active workout: \(error)")
                    }
                }
            case "clearActiveWorkout", "workoutFinished", "workoutCancelled":
                self.activeWorkout = nil
            default:
                break
            }
        }
    }

    // MARK: - Actions Sent to iPhone

    func startWorkout(routineId: String) {
        sendToiPhone(["action": "startWorkout", "routineId": routineId])
    }

    func toggleSet(exerciseIndex: Int, setIndex: Int) {
        sendToiPhone([
            "action": "toggleSet",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex
        ])
    }

    func completeWorkout() {
        sendToiPhone(["action": "completeWorkout"])
    }

    func cancelWorkout() {
        sendToiPhone(["action": "cancelWorkout"])
    }

    private func sendToiPhone(_ message: [String: Any]) {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message to iPhone: \(error.localizedDescription)")
            }
        } else {
            // Fallback for background user info transfer
            session.transferUserInfo(message)
        }
    }
}

// MARK: - Decodable Models

struct WatchRoutine: Codable, Identifiable {
    let id: String
    let name: String
    let defaultRest: Int
    let exercises: [WatchRoutineExercise]
}

struct WatchRoutineExercise: Codable, Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let sets: Int
    let reps: Int
    let rest: Int
    let weight: Double
}

struct WatchActiveWorkoutState: Codable {
    let name: String
    let startTime: Int
    let exercises: [WatchActiveExercise]
    let currentExerciseIndex: Int
    let elapsedSeconds: Int
    let paused: Bool
}

struct WatchActiveExercise: Codable, Identifiable {
    var id: String { name }
    let name: String
    let muscle: String
    let sets: Int
    let reps: Int
    let rest: Int
    let weight: Double
    let setsState: [Bool]
}
