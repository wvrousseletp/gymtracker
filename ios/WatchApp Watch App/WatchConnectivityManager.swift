import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var routines: [WatchRoutine] = []
    @Published var library: [WatchLibraryExercise] = []
    @Published var planner: [String: [String]] = [:]
    @Published var activeWorkout: WatchActiveWorkoutState?
    @Published var isReachable = false

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
            // Check if session is already activated and load cached application context
            if session?.activationState == .activated {
                if let context = session?.receivedApplicationContext {
                    handleIncomingData(context)
                }
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.handleIncomingData(session.receivedApplicationContext)
                self.requestSync()
            }
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
            if session.isReachable {
                self.requestSync()
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingData(applicationContext)
    }

    private func handleIncomingData(_ data: [String : Any]) {
        DispatchQueue.main.async {
            // 1. Process routines
            if let jsonString = data["routines"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.routines = try JSONDecoder().decode([WatchRoutine].self, from: jsonData)
                } catch {
                    print("Error decoding routines: \(error)")
                }
            }

            // 2. Process library
            if let jsonString = data["library"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                } catch {
                    print("Error decoding library: \(error)")
                }
            }

            // 2.1 Process planner
            if let jsonString = data["planner"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                } catch {
                    print("Error decoding planner: \(error)")
                }
            }

            let oldWorkout = self.activeWorkout
            var receivedActiveWorkout = false

            // 3. Process active workout / clear active workout
            if let jsonString = data["activeWorkout"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.activeWorkout = try JSONDecoder().decode(WatchActiveWorkoutState.self, from: jsonData)
                    receivedActiveWorkout = true
                } catch {
                    print("Error decoding active workout: \(error)")
                }
            } else if data["clearActiveWorkout"] as? Bool == true {
                self.activeWorkout = nil
                receivedActiveWorkout = true
            }

            // 4. Process action field for compatibility (e.g. workoutFinished, workoutCancelled)
            var actionStr: String? = nil
            if let action = data["action"] as? String {
                actionStr = action
                switch action {
                case "updateRoutines":
                    if let jsonString = data["routines"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.routines = try JSONDecoder().decode([WatchRoutine].self, from: jsonData)
                        } catch {
                            print("Error decoding routines in action: \(error)")
                        }
                    }
                case "updateLibrary":
                    if let jsonString = data["library"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                        } catch {
                            print("Error decoding library in action: \(error)")
                        }
                    }
                case "updatePlanner":
                    if let jsonString = data["planner"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                        } catch {
                            print("Error decoding planner in action: \(error)")
                        }
                    }
                case "updateActiveWorkout":
                    if let jsonString = data["activeWorkout"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.activeWorkout = try JSONDecoder().decode(WatchActiveWorkoutState.self, from: jsonData)
                            receivedActiveWorkout = true
                        } catch {
                            print("Error decoding active workout in action: \(error)")
                        }
                    }
                case "clearActiveWorkout", "workoutFinished", "workoutCancelled", "workoutPostponed":
                    self.activeWorkout = nil
                default:
                    break
                }
            }

            if receivedActiveWorkout || actionStr == "clearActiveWorkout" || actionStr == "workoutFinished" || actionStr == "workoutCancelled" || actionStr == "workoutPostponed" {
                self.handleWorkoutSessionTransition(oldWorkout: oldWorkout, newWorkout: self.activeWorkout, action: actionStr)
            }
        }
    }

    private func handleWorkoutSessionTransition(oldWorkout: WatchActiveWorkoutState?, newWorkout: WatchActiveWorkoutState?, action: String? = nil) {
        if oldWorkout == nil && newWorkout != nil {
            // Workout started!
            if let new = newWorkout, !new.postponed {
                WorkoutManager.shared.startWorkout()
            }
        } else if oldWorkout != nil && newWorkout == nil {
            // Workout ended!
            let shouldSave = (action == "workoutFinished" || action == "completeWorkout")
            WorkoutManager.shared.endWorkout(save: shouldSave)
        } else if let old = oldWorkout, let new = newWorkout {
            // Transition within workout: check pause status
            if old.paused != new.paused {
                if new.paused {
                    WorkoutManager.shared.pauseWorkout()
                } else {
                    WorkoutManager.shared.resumeWorkout()
                }
            }
            // Transition within workout: check postponed status
            if !old.postponed && new.postponed {
                WorkoutManager.shared.endWorkout(save: true)
            } else if old.postponed && !new.postponed {
                WorkoutManager.shared.startWorkout()
            }
        }
    }

    // MARK: - Actions Sent to iPhone

    func startWorkout(routineId: String) {
        sendToiPhone(["action": "startWorkout", "routineId": routineId])
    }

    func startSingleExercise(exerciseId: String) {
        sendToiPhone(["action": "startSingleExercise", "exerciseId": exerciseId])
    }

    func toggleSet(exerciseIndex: Int, setIndex: Int, isDone: Bool, isFailure: Bool, failureRep: Int?, distance: Double?, duration: Int?) {
        var msg: [String: Any] = [
            "action": "toggleSet",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "isDone": isDone,
            "isFailure": isFailure
        ]
        if let rep = failureRep {
            msg["failureRep"] = rep
        }
        if let dist = distance {
            msg["distance"] = dist
        }
        if let dur = duration {
            msg["duration"] = dur
        }
        sendToiPhone(msg)
    }

    func updateCardio(exerciseIndex: Int, setIndex: Int, distance: Double, duration: Int) {
        sendToiPhone([
            "action": "updateCardio",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "distance": distance,
            "duration": duration
        ])
    }

    func updateFailure(exerciseIndex: Int, setIndex: Int, isFailure: Bool, failureRep: Int?) {
        var msg: [String: Any] = [
            "action": "updateFailure",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "isFailure": isFailure
        ]
        if let rep = failureRep {
            msg["failureRep"] = rep
        }
        sendToiPhone(msg)
    }

    func updateExerciseWeightReps(exerciseIndex: Int, weight: Double, reps: Int) {
        sendToiPhone([
            "action": "updateExerciseWeightReps",
            "exerciseIndex": exerciseIndex,
            "weight": weight,
            "reps": reps
        ])
    }

    func skipRest() {
        sendToiPhone(["action": "skipRest"])
    }

    func completeWorkout() {
        sendToiPhone(["action": "completeWorkout"])
    }

    func cancelWorkout() {
        sendToiPhone(["action": "cancelWorkout"])
    }

    func postponeWorkout() {
        sendToiPhone(["action": "postponeWorkout"])
    }

    func resumeWorkout() {
        sendToiPhone(["action": "resumeWorkout"])
    }

    func togglePause(currentlyPaused: Bool) {
        sendToiPhone(["action": "togglePause", "paused": !currentlyPaused])
    }

    func requestSync() {
        sendToiPhone(["action": "requestSync"])
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

    enum CodingKeys: String, CodingKey {
        case id, name, defaultRest, exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        if let val = try? container.decode(Int.self, forKey: .defaultRest) {
            defaultRest = val
        } else if let val = try? container.decode(Double.self, forKey: .defaultRest) {
            defaultRest = Int(val)
        } else {
            defaultRest = 60
        }

        exercises = (try? container.decode([WatchRoutineExercise].self, forKey: .exercises)) ?? []
    }
}

struct WatchRoutineExercise: Codable, Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let sets: Int
    let reps: Int
    let rest: Int
    let weight: Double

    enum CodingKeys: String, CodingKey {
        case exerciseId, sets, reps, rest, weight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        
        if let val = try? container.decode(Int.self, forKey: .sets) {
            sets = val
        } else if let val = try? container.decode(Double.self, forKey: .sets) {
            sets = Int(val)
        } else {
            sets = 3
        }

        if let val = try? container.decode(Int.self, forKey: .reps) {
            reps = val
        } else if let val = try? container.decode(Double.self, forKey: .reps) {
            reps = Int(val)
        } else {
            reps = 10
        }

        if let val = try? container.decode(Int.self, forKey: .rest) {
            rest = val
        } else if let val = try? container.decode(Double.self, forKey: .rest) {
            rest = Int(val)
        } else {
            rest = 60
        }

        if let val = try? container.decode(Double.self, forKey: .weight) {
            weight = val
        } else if let val = try? container.decode(Int.self, forKey: .weight) {
            weight = Double(val)
        } else {
            weight = 0.0
        }
    }
}

struct WatchLibraryExercise: Codable, Identifiable {
    let id: String
    let name: String
    let muscle: String
    let executionType: String
    let measurementType: String

    enum CodingKeys: String, CodingKey {
        case id, name, muscle, executionType, measurementType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscle = try container.decode(String.self, forKey: .muscle)
        executionType = (try? container.decode(String.self, forKey: .executionType)) ?? "Livre"
        measurementType = (try? container.decode(String.self, forKey: .measurementType)) ?? "reps"
    }
}

struct WatchRestTimer: Codable {
    let endTime: Int64
    let totalSeconds: Int
    let nextExerciseName: String
    let nextSetNum: Int
    let isPrep: Bool

    enum CodingKeys: String, CodingKey {
        case endTime, totalSeconds, nextExerciseName, nextSetNum, isPrep
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let val = try? container.decode(Int64.self, forKey: .endTime) {
            endTime = val
        } else if let val = try? container.decode(Double.self, forKey: .endTime) {
            endTime = Int64(val)
        } else {
            endTime = 0
        }

        if let val = try? container.decode(Int.self, forKey: .totalSeconds) {
            totalSeconds = val
        } else if let val = try? container.decode(Double.self, forKey: .totalSeconds) {
            totalSeconds = Int(val)
        } else {
            totalSeconds = 0
        }

        nextExerciseName = (try? container.decode(String.self, forKey: .nextExerciseName)) ?? ""
        
        if let val = try? container.decode(Int.self, forKey: .nextSetNum) {
            nextSetNum = val
        } else if let val = try? container.decode(Double.self, forKey: .nextSetNum) {
            nextSetNum = Int(val)
        } else {
            nextSetNum = 0
        }

        isPrep = (try? container.decode(Bool.self, forKey: .isPrep)) ?? false
    }
}

struct WatchPerformedCardio: Codable {
    let distanceKm: Double
    let durationSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case distanceKm, durationSeconds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let val = try? container.decode(Double.self, forKey: .distanceKm) {
            distanceKm = val
        } else if let val = try? container.decode(Int.self, forKey: .distanceKm) {
            distanceKm = Double(val)
        } else {
            distanceKm = 0.0
        }
        
        if let val = try? container.decode(Int.self, forKey: .durationSeconds) {
            durationSeconds = val
        } else if let val = try? container.decode(Double.self, forKey: .durationSeconds) {
            durationSeconds = Int(val)
        } else {
            durationSeconds = 0
        }
    }
    
    init(distanceKm: Double, durationSeconds: Int) {
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
    }
}

struct WatchActiveWorkoutState: Codable {
    let name: String
    let startTime: Int64
    let exercises: [WatchActiveExercise]
    let currentExerciseIndex: Int
    let elapsedSeconds: Int
    let paused: Bool
    let restTimer: WatchRestTimer?
    let postponed: Bool

    enum CodingKeys: String, CodingKey {
        case name, startTime, exercises, currentExerciseIndex, elapsedSeconds, paused, restTimer, postponed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        
        if let val = try? container.decode(Int64.self, forKey: .startTime) {
            startTime = val
        } else if let val = try? container.decode(Double.self, forKey: .startTime) {
            startTime = Int64(val)
        } else {
            startTime = 0
        }

        exercises = (try? container.decode([WatchActiveExercise].self, forKey: .exercises)) ?? []
        
        if let val = try? container.decode(Int.self, forKey: .currentExerciseIndex) {
            currentExerciseIndex = val
        } else if let val = try? container.decode(Double.self, forKey: .currentExerciseIndex) {
            currentExerciseIndex = Int(val)
        } else {
            currentExerciseIndex = 0
        }

        if let val = try? container.decode(Int.self, forKey: .elapsedSeconds) {
            elapsedSeconds = val
        } else if let val = try? container.decode(Double.self, forKey: .elapsedSeconds) {
            elapsedSeconds = Int(val)
        } else {
            elapsedSeconds = 0
        }

        paused = (try? container.decode(Bool.self, forKey: .paused)) ?? false
        restTimer = try? container.decodeIfPresent(WatchRestTimer.self, forKey: .restTimer)
        postponed = (try? container.decode(Bool.self, forKey: .postponed)) ?? false
    }
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
    let measurementType: String
    let executionType: String?
    let performedCardios: [WatchPerformedCardio?]
    let failureReport: [Bool]
    let failureReps: [Int?]

    enum CodingKeys: String, CodingKey {
        case name, muscle, sets, reps, rest, weight, setsState, measurementType, executionType, performedCardios, failureReport, failureReps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        muscle = try container.decode(String.self, forKey: .muscle)
        setsState = try container.decode([Bool].self, forKey: .setsState)
        measurementType = (try? container.decode(String.self, forKey: .measurementType)) ?? (muscle.lowercased().contains("cardio") ? "time" : "reps")
        executionType = try? container.decodeIfPresent(String.self, forKey: .executionType)

        if let val = try? container.decode(Int.self, forKey: .sets) {
            sets = val
        } else if let val = try? container.decode(Double.self, forKey: .sets) {
            sets = Int(val)
        } else {
            sets = setsState.count
        }

        if let val = try? container.decode(Int.self, forKey: .reps) {
            reps = val
        } else if let val = try? container.decode(Double.self, forKey: .reps) {
            reps = Int(val)
        } else {
            reps = 10
        }

        if let val = try? container.decode(Int.self, forKey: .rest) {
            rest = val
        } else if let val = try? container.decode(Double.self, forKey: .rest) {
            rest = Int(val)
        } else {
            rest = 60
        }

        if let val = try? container.decode(Double.self, forKey: .weight) {
            weight = val
        } else if let val = try? container.decode(Int.self, forKey: .weight) {
            weight = Double(val)
        } else {
            weight = 0.0
        }

        if let cardiosArray = try? container.decode([WatchPerformedCardio?].self, forKey: .performedCardios) {
            performedCardios = cardiosArray
        } else {
            performedCardios = Array(repeating: nil, count: setsState.count)
        }

        failureReport = (try? container.decode([Bool].self, forKey: .failureReport)) ?? Array(repeating: false, count: setsState.count)
        
        if let repsArray = try? container.decode([Int?].self, forKey: .failureReps) {
            failureReps = repsArray
        } else {
            failureReps = Array(repeating: nil, count: setsState.count)
        }
    }
}
