import Foundation
import WatchConnectivity
import Combine
#if os(watchOS)
import WatchKit
#endif

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var routines: [WatchRoutine] = []
    @Published var library: [WatchLibraryExercise] = []
    @Published var planner: [String: [String]] = [:]
    @Published var isReachable = false
    @Published var isLocalWorkout = false
    @Published var streak: WatchStreak = WatchStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: "")
    /// Lista de exercícios com PR recém-batido – resetada após exibição da celebração
    @Published var prExerciseNames: [String] = []

    @Published var activeWorkout: WatchActiveWorkoutState? {
        didSet {
            if isLocalWorkout {
                saveLocalActiveWorkoutToDisk()
            } else if activeWorkout == nil {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "local_workout_state")
                defaults.set(false, forKey: "local_workout_is_local")
                defaults.synchronize()
            }
        }
    }

    private var session: WCSession?

    private override init() {
        super.init()
        
        // Load cached data from UserDefaults
        let defaults = UserDefaults.standard
        if let routinesJson = defaults.string(forKey: "cached_routines"),
           let jsonData = routinesJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WatchRoutine].self, from: jsonData) {
            self.routines = decoded
        }
        if let libraryJson = defaults.string(forKey: "cached_library"),
           let jsonData = libraryJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData) {
            self.library = decoded
        }
        if let plannerJson = defaults.string(forKey: "cached_planner"),
           let jsonData = plannerJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: jsonData) {
            self.planner = decoded
        }
        
        self.isLocalWorkout = defaults.bool(forKey: "local_workout_is_local")
        if let savedData = defaults.data(forKey: "local_workout_state"),
           let active = try? JSONDecoder().decode(WatchActiveWorkoutState.self, from: savedData) {
            self.activeWorkout = active
        }
        
        // Carrega streak em cache
        if let streakJson = defaults.string(forKey: "cached_streak"),
           let jsonData = streakJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(WatchStreak.self, from: jsonData) {
            self.streak = decoded
        }
        
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
        
        syncOfflineWorkouts()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.handleIncomingData(session.receivedApplicationContext)
                self.requestSync()
                self.syncOfflineWorkouts()
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
                self.syncOfflineWorkouts()

                // If we have an in-progress local workout, push its full state to the
                // iPhone so it can mirror the progress and take over control.
                if self.isLocalWorkout, let active = self.activeWorkout,
                   let data = try? JSONEncoder().encode(active),
                   let json = String(data: data, encoding: .utf8) {
                    print("[WCM] Reconnected with local workout '\(active.name)' — pushing state to iPhone")
                    session.transferUserInfo([
                        "action": "updateActiveWorkout",
                        "activeWorkout": json
                    ])
                    // Hand control back to iPhone; it will confirm by sending back activeWorkout
                    self.isLocalWorkout = false
                }
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
                    UserDefaults.standard.set(jsonString, forKey: "cached_routines")
                } catch {
                    print("Error decoding routines: \(error)")
                }
            }

            // 2. Process library
            if let jsonString = data["library"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                    UserDefaults.standard.set(jsonString, forKey: "cached_library")
                } catch {
                    print("Error decoding library: \(error)")
                }
            }

            // 2.1 Process planner
            if let jsonString = data["planner"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                    UserDefaults.standard.set(jsonString, forKey: "cached_planner")
                } catch {
                    print("Error decoding planner: \(error)")
                }
            }

            let oldWorkout = self.activeWorkout
            var receivedActiveWorkout = false

            // 3. Process active workout / clear active workout
            if !self.isLocalWorkout {
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
                            UserDefaults.standard.set(jsonString, forKey: "cached_routines")
                        } catch {
                            print("Error decoding routines in action: \(error)")
                        }
                    }
                case "updateLibrary":
                    if let jsonString = data["library"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                            UserDefaults.standard.set(jsonString, forKey: "cached_library")
                        } catch {
                            print("Error decoding library in action: \(error)")
                        }
                    }
                case "updatePlanner":
                    if let jsonString = data["planner"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                            UserDefaults.standard.set(jsonString, forKey: "cached_planner")
                        } catch {
                            print("Error decoding planner in action: \(error)")
                        }
                    }
                case "updateActiveWorkout":
                    if !self.isLocalWorkout {
                        if let jsonString = data["activeWorkout"] as? String,
                           let jsonData = jsonString.data(using: .utf8) {
                            do {
                                self.activeWorkout = try JSONDecoder().decode(WatchActiveWorkoutState.self, from: jsonData)
                                receivedActiveWorkout = true
                            } catch {
                                print("Error decoding active workout in action: \(error)")
                            }
                        }
                    }
                case "clearActiveWorkout", "workoutFinished", "workoutCancelled", "workoutPostponed":
                    if !self.isLocalWorkout {
                        self.activeWorkout = nil
                    }

                case "prCelebration":
                    // Dispara háptico de celebração de PR e exibe o banner
                    let names = data["exerciseNames"] as? [String] ?? []
                    if !names.isEmpty {
                        self.prExerciseNames = names
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            WKInterfaceDevice.current().play(.success)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            WKInterfaceDevice.current().play(.notification)
                        }
                        #endif
                        // Reseta após 4 segundos para limpar o banner
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            self.prExerciseNames = []
                        }
                    }

                case "updateStreak":
                    if let streakJson = data["streak"] as? String,
                       let jsonData = streakJson.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(WatchStreak.self, from: jsonData) {
                        self.streak = decoded
                        UserDefaults.standard.set(streakJson, forKey: "cached_streak")
                    }

                default:
                    break
                }
            }

            if !self.isLocalWorkout && (receivedActiveWorkout || actionStr == "clearActiveWorkout" || actionStr == "workoutFinished" || actionStr == "workoutCancelled" || actionStr == "workoutPostponed") {
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

    // MARK: - Actions Sent to iPhone

    func startWorkout(routineId: String) {
        if isReachable {
            sendToiPhone(["action": "startWorkout", "routineId": routineId])
        } else {
            isLocalWorkout = true
            startLocalWorkout(routineId: routineId)
        }
    }

    func startSingleExercise(exerciseId: String) {
        if isReachable {
            sendToiPhone(["action": "startSingleExercise", "exerciseId": exerciseId])
        } else {
            isLocalWorkout = true
            startLocalSingleExercise(exerciseId: exerciseId)
        }
    }

    func toggleSet(exerciseIndex: Int, setIndex: Int, isDone: Bool, isFailure: Bool, failureRep: Int?, distance: Double?, duration: Int?) {
        if isLocalWorkout {
            toggleSetLocal(exerciseIndex: exerciseIndex, setIndex: setIndex, isDone: isDone, isFailure: isFailure, failureRep: failureRep, distance: distance, duration: duration)
        } else {
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
    }

    func updateCardio(exerciseIndex: Int, setIndex: Int, distance: Double, duration: Int) {
        if isLocalWorkout {
            toggleSetLocal(exerciseIndex: exerciseIndex, setIndex: setIndex, isDone: true, isFailure: false, failureRep: nil, distance: distance, duration: duration)
        } else {
            sendToiPhone([
                "action": "updateCardio",
                "exerciseIndex": exerciseIndex,
                "setIndex": setIndex,
                "distance": distance,
                "duration": duration
            ])
        }
    }

    func updateFailure(exerciseIndex: Int, setIndex: Int, isFailure: Bool, failureRep: Int?) {
        if isLocalWorkout {
            toggleSetLocal(exerciseIndex: exerciseIndex, setIndex: setIndex, isDone: true, isFailure: isFailure, failureRep: failureRep, distance: nil, duration: nil)
        } else {
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
    }

    func updateExerciseWeightReps(exerciseIndex: Int, weight: Double, reps: Int) {
        if isLocalWorkout {
            updateExerciseWeightRepsLocal(exerciseIndex: exerciseIndex, weight: weight, reps: reps)
        } else {
            sendToiPhone([
                "action": "updateExerciseWeightReps",
                "exerciseIndex": exerciseIndex,
                "weight": weight,
                "reps": reps
            ])
        }
    }

    func skipRest() {
        if isLocalWorkout {
            skipRestLocal()
        } else {
            // Immediately clear the local rest timer so the Watch UI transitions
            // away from RestTimerView without waiting for the iPhone to respond.
            if let active = activeWorkout {
                activeWorkout = WatchActiveWorkoutState(
                    name: active.name,
                    startTime: active.startTime,
                    exercises: active.exercises,
                    currentExerciseIndex: active.currentExerciseIndex,
                    elapsedSeconds: active.elapsedSeconds,
                    paused: active.paused,
                    restTimer: nil,
                    postponed: active.postponed
                )
            }
            sendToiPhone(["action": "skipRest"])
        }
    }

    func completeWorkout() {
        if isLocalWorkout {
            completeLocalWorkout()
        } else {
            sendToiPhone(["action": "completeWorkout"])
        }
    }

    func cancelWorkout() {
        if isLocalWorkout {
            cancelWorkoutLocal()
        } else {
            sendToiPhone(["action": "cancelWorkout"])
        }
    }

    func postponeWorkout() {
        if isLocalWorkout {
            postponeWorkoutLocal()
        } else {
            sendToiPhone(["action": "postponeWorkout"])
        }
    }

    func resumeWorkout() {
        if isLocalWorkout {
            resumeWorkoutLocal()
        } else {
            sendToiPhone(["action": "resumeWorkout"])
        }
    }

    func togglePause(currentlyPaused: Bool) {
        if isLocalWorkout {
            togglePauseLocal(currentlyPaused: currentlyPaused)
        } else {
            sendToiPhone(["action": "togglePause", "paused": !currentlyPaused])
        }
    }

    func changeExercise(to index: Int) {
        if isLocalWorkout {
            changeExerciseLocal(to: index)
        } else {
            sendToiPhone(["action": "changeExercise", "exerciseIndex": index])
        }
    }

    func requestSync() {
        sendToiPhone(["action": "requestSync"])
    }

    func sendHealthMetrics(heartRate: Double, calories: Double) {
        sendToiPhone([
            "action": "updateHealthMetrics",
            "heartRate": heartRate,
            "activeCalories": calories
        ])
    }

    private func sendToiPhone(_ message: [String: Any]) {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                // sendMessage failed (e.g. iOS app was backgrounded/suspended).
                // Fall back to guaranteed-delivery transferUserInfo so the action
                // is not silently lost.
                print("[WCM] sendMessage failed (\(error.localizedDescription)) – retrying via transferUserInfo")
                DispatchQueue.global().async {
                    session.transferUserInfo(message)
                }
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Local Workout Implementations

    private func saveLocalActiveWorkoutToDisk() {
        let defaults = UserDefaults.standard
        defaults.set(isLocalWorkout, forKey: "local_workout_is_local")
        if let active = activeWorkout {
            if let encoded = try? JSONEncoder().encode(active) {
                defaults.set(encoded, forKey: "local_workout_state")
            }
        } else {
            defaults.removeObject(forKey: "local_workout_state")
        }
        defaults.synchronize()
    }

    private func startLocalWorkout(routineId: String) {
        guard let routine = routines.first(where: { $0.id == routineId }) else { return }
        
        var activeExercises: [WatchActiveExercise] = []
        for re in routine.exercises {
            let libEx = library.first(where: { $0.id == re.exerciseId })
            let name = libEx?.name ?? "Exercício"
            let muscle = libEx?.muscle ?? "Geral"
            let measurementType = libEx?.measurementType ?? "reps"
            let executionType = libEx?.executionType
            
            let activeEx = WatchActiveExercise(
                name: name,
                muscle: muscle,
                sets: re.sets,
                reps: re.reps,
                rest: re.rest,
                weight: re.weight,
                setsState: Array(repeating: false, count: re.sets),
                measurementType: measurementType,
                executionType: executionType,
                performedCardios: Array(repeating: nil, count: re.sets),
                failureReport: Array(repeating: false, count: re.sets),
                failureReps: Array(repeating: nil, count: re.sets)
            )
            activeExercises.append(activeEx)
        }
        
        let state = WatchActiveWorkoutState(
            name: routine.name,
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            exercises: activeExercises,
            currentExerciseIndex: 0,
            elapsedSeconds: 0,
            paused: false,
            restTimer: nil,
            postponed: false
        )
        
        self.activeWorkout = state
        WorkoutManager.shared.startWorkout()
    }

    private func startLocalSingleExercise(exerciseId: String) {
        guard let libEx = library.first(where: { $0.id == exerciseId }) else { return }
        
        let activeEx = WatchActiveExercise(
            name: libEx.name,
            muscle: libEx.muscle,
            sets: 3,
            reps: 10,
            rest: 60,
            weight: 0.0,
            setsState: [false, false, false],
            measurementType: libEx.measurementType,
            executionType: libEx.executionType,
            performedCardios: [nil, nil, nil],
            failureReport: [false, false, false],
            failureReps: [nil, nil, nil]
        )
        
        let state = WatchActiveWorkoutState(
            name: libEx.name,
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            exercises: [activeEx],
            currentExerciseIndex: 0,
            elapsedSeconds: 0,
            paused: false,
            restTimer: nil,
            postponed: false
        )
        
        self.activeWorkout = state
        WorkoutManager.shared.startWorkout()
    }

    private func toggleSetLocal(exerciseIndex: Int, setIndex: Int, isDone: Bool, isFailure: Bool, failureRep: Int?, distance: Double?, duration: Int?) {
        guard var active = activeWorkout else { return }
        guard exerciseIndex < active.exercises.count else { return }
        var exercises = active.exercises
        var ex = exercises[exerciseIndex]
        
        var setsState = ex.setsState
        if setIndex < setsState.count {
            setsState[setIndex] = isDone
        }
        
        var failureReport = ex.failureReport
        if setIndex < failureReport.count {
            failureReport[setIndex] = isFailure
        }
        
        var failureReps = ex.failureReps
        if setIndex < failureReps.count {
            failureReps[setIndex] = failureRep
        }
        
        var performedCardios = ex.performedCardios
        if setIndex < performedCardios.count {
            if let dist = distance, let dur = duration {
                performedCardios[setIndex] = WatchPerformedCardio(distanceKm: dist, durationSeconds: dur)
            } else if distance != nil || duration != nil {
                performedCardios[setIndex] = WatchPerformedCardio(distanceKm: distance ?? 0.0, durationSeconds: duration ?? 0)
            }
        }
        
        let updatedEx = WatchActiveExercise(
            name: ex.name,
            muscle: ex.muscle,
            sets: ex.sets,
            reps: ex.reps,
            rest: ex.rest,
            weight: ex.weight,
            setsState: setsState,
            measurementType: ex.measurementType,
            executionType: ex.executionType,
            performedCardios: performedCardios,
            failureReport: failureReport,
            failureReps: failureReps
        )
        exercises[exerciseIndex] = updatedEx
        
        var restTimer: WatchRestTimer? = nil
        if isDone {
            let nextSetNum = setIndex + 2
            let restDuration = ex.rest
            if nextSetNum <= ex.sets {
                let endTime = Int64(Date().timeIntervalSince1970 * 1000) + Int64(restDuration * 1000)
                restTimer = WatchRestTimer(endTime: endTime, totalSeconds: restDuration, nextExerciseName: ex.name, nextSetNum: nextSetNum, isPrep: false)
            } else if exerciseIndex + 1 < exercises.count {
                let nextEx = exercises[exerciseIndex + 1]
                let endTime = Int64(Date().timeIntervalSince1970 * 1000) + Int64(restDuration * 1000)
                restTimer = WatchRestTimer(endTime: endTime, totalSeconds: restDuration, nextExerciseName: nextEx.name, nextSetNum: 1, isPrep: false)
            }
        }
        
        var currentExIdx = active.currentExerciseIndex
        if isDone && setsState.allSatisfy({ $0 }) {
            if currentExIdx + 1 < exercises.count {
                currentExIdx += 1
            }
        }
        
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: active.startTime,
            exercises: exercises,
            currentExerciseIndex: currentExIdx,
            elapsedSeconds: elapsed,
            paused: active.paused,
            restTimer: restTimer,
            postponed: active.postponed
        )

        // Mirror the updated state to iPhone via transferUserInfo so the iOS side
        // stays in sync even while we're in local/offline mode.
        if let updatedActive = activeWorkout,
           let data = try? JSONEncoder().encode(updatedActive),
           let json = String(data: data, encoding: .utf8),
           let sess = session {
            sess.transferUserInfo([
                "action": "updateActiveWorkout",
                "activeWorkout": json
            ])
        }
    }

    private func updateExerciseWeightRepsLocal(exerciseIndex: Int, weight: Double, reps: Int) {
        guard var active = activeWorkout else { return }
        guard exerciseIndex < active.exercises.count else { return }
        var exercises = active.exercises
        var ex = exercises[exerciseIndex]
        
        let updatedEx = WatchActiveExercise(
            name: ex.name,
            muscle: ex.muscle,
            sets: ex.sets,
            reps: reps,
            rest: ex.rest,
            weight: weight,
            setsState: ex.setsState,
            measurementType: ex.measurementType,
            executionType: ex.executionType,
            performedCardios: ex.performedCardios,
            failureReport: ex.failureReport,
            failureReps: ex.failureReps
        )
        exercises[exerciseIndex] = updatedEx
        
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: active.startTime,
            exercises: exercises,
            currentExerciseIndex: active.currentExerciseIndex,
            elapsedSeconds: elapsed,
            paused: active.paused,
            restTimer: active.restTimer,
            postponed: active.postponed
        )
    }

    private func skipRestLocal() {
        guard var active = activeWorkout else { return }
        
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: active.startTime,
            exercises: active.exercises,
            currentExerciseIndex: active.currentExerciseIndex,
            elapsedSeconds: elapsed,
            paused: active.paused,
            restTimer: nil,
            postponed: active.postponed
        )
    }

    private func completeLocalWorkout() {
        guard let active = activeWorkout else { return }
        
        let now = Date()
        let duration = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        var totalSets = 0
        var completedSets = 0
        var totalWeightVolume = 0.0
        
        var exercisesJson: [[String: Any]] = []
        
        for ex in active.exercises {
            let done = ex.setsState.filter { $0 }.count
            totalSets += ex.sets
            completedSets += done
            
            let isCardio = ex.muscle.lowercased().contains("cardio")
            var finalWeight = ex.weight
            var finalReps = ex.reps
            
            var performedCardiosJson: [Any] = []
            for pc in ex.performedCardios {
                if let card = pc {
                    performedCardiosJson.append([
                        "distanceKm": card.distanceKm,
                        "durationSeconds": card.durationSeconds
                    ])
                } else {
                    performedCardiosJson.append(NSNull())
                }
            }
            
            if isCardio {
                let completedList = ex.performedCardios.compactMap { $0 }
                if !completedList.isEmpty {
                    let totalDist = completedList.reduce(0.0) { $0 + $1.distanceKm }
                    let totalDurMin = completedList.reduce(0) { $0 + ($1.durationSeconds / 60) }
                    finalWeight = totalDist / Double(completedList.count)
                    finalReps = totalDurMin / completedList.count
                }
            } else {
                for i in 0..<ex.sets {
                    if i < ex.setsState.count && ex.setsState[i] {
                        totalWeightVolume += ex.weight * Double(ex.reps)
                    }
                }
            }
            
            var failureRepsJson: [Any] = []
            for rep in ex.failureReps {
                if let r = rep {
                    failureRepsJson.append(r)
                } else {
                    failureRepsJson.append(NSNull())
                }
            }
            
            let exJson: [String: Any] = [
                "name": ex.name,
                "muscle": ex.muscle,
                "sets": ex.sets,
                "completedSets": done,
                "reps": finalReps,
                "weight": finalWeight,
                "performedCardios": performedCardiosJson,
                "rpe": 8,
                "failureReport": ex.failureReport,
                "failureReps": failureRepsJson,
                "executionType": ex.executionType ?? ""
            ]
            exercisesJson.append(exJson)
        }
        
        let isoFormatter = ISO8601DateFormatter()
        let dateStr = isoFormatter.string(from: now)
        
        let workoutLogJson: [String: Any] = [
            "id": "watch-log-\(Int64(now.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6))",
            "name": active.name,
            "date": dateStr,
            "duration": duration,
            "completedSets": completedSets,
            "totalSets": totalSets,
            "totalWeight": totalWeightVolume,
            "rpe": 8,
            "notes": "Treino concluído em modo offline via Apple Watch",
            "exercises": exercisesJson
        ]
        
        saveOfflineWorkoutToCache(workoutLogJson)
        
        self.activeWorkout = nil
        isLocalWorkout = false
        
        WorkoutManager.shared.endWorkout(save: true)
        
        syncOfflineWorkouts()
    }

    private func cancelWorkoutLocal() {
        activeWorkout = nil
        isLocalWorkout = false
        WorkoutManager.shared.endWorkout(save: false)
    }

    private func postponeWorkoutLocal() {
        guard var active = activeWorkout else { return }
        
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: active.startTime,
            exercises: active.exercises,
            currentExerciseIndex: active.currentExerciseIndex,
            elapsedSeconds: elapsed,
            paused: active.paused,
            restTimer: active.restTimer,
            postponed: true
        )
        
        saveLocalActiveWorkoutToDisk()
        WorkoutManager.shared.endWorkout(save: true)
    }

    private func resumeWorkoutLocal() {
        guard var active = activeWorkout else { return }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let startTime = now - Int64(active.elapsedSeconds * 1000)
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: startTime,
            exercises: active.exercises,
            currentExerciseIndex: active.currentExerciseIndex,
            elapsedSeconds: active.elapsedSeconds,
            paused: active.paused,
            restTimer: active.restTimer,
            postponed: false
        )
        
        WorkoutManager.shared.startWorkout()
    }

    private func togglePauseLocal(currentlyPaused: Bool) {
        guard var active = activeWorkout else { return }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        let newPaused = !currentlyPaused
        let newStartTime = newPaused ? active.startTime : (now - Int64(elapsed * 1000))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: newStartTime,
            exercises: active.exercises,
            currentExerciseIndex: active.currentExerciseIndex,
            elapsedSeconds: elapsed,
            paused: newPaused,
            restTimer: active.restTimer,
            postponed: active.postponed
        )
        
        if newPaused {
            WorkoutManager.shared.pauseWorkout()
        } else {
            WorkoutManager.shared.resumeWorkout()
        }
    }

    private func changeExerciseLocal(to index: Int) {
        guard var active = activeWorkout else { return }
        guard index >= 0 && index < active.exercises.count else { return }
        
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - Double(active.startTime / 1000)))
        
        activeWorkout = WatchActiveWorkoutState(
            name: active.name,
            startTime: active.startTime,
            exercises: active.exercises,
            currentExerciseIndex: index,
            elapsedSeconds: elapsed,
            paused: active.paused,
            restTimer: active.restTimer,
            postponed: active.postponed
        )
    }

    private func saveOfflineWorkoutToCache(_ workout: [String: Any]) {
        let defaults = UserDefaults.standard
        var cachedWorkouts = defaults.array(forKey: "offline_workout_cache") as? [[String: Any]] ?? []
        cachedWorkouts.append(workout)
        defaults.set(cachedWorkouts, forKey: "offline_workout_cache")
        defaults.synchronize()
        print("[WatchConnectivityManager] Saved workout to offline cache. Current cache size: \(cachedWorkouts.count)")
    }

    func syncOfflineWorkouts() {
        let defaults = UserDefaults.standard
        guard let cachedWorkouts = defaults.array(forKey: "offline_workout_cache") as? [[String: Any]], !cachedWorkouts.isEmpty else {
            return
        }
        
        guard let session = session else { return }
        
        print("[WatchConnectivityManager] Attempting to sync \(cachedWorkouts.count) cached workouts...")
        
        for workout in cachedWorkouts {
            let message: [String: Any] = [
                "action": "syncOfflineWorkout",
                "workoutData": workout
            ]
            session.transferUserInfo(message)
        }
        
        defaults.set([], forKey: "offline_workout_cache")
        defaults.synchronize()
        print("[WatchConnectivityManager] Transferred cached workouts and cleared local cache.")
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

    init(endTime: Int64, totalSeconds: Int, nextExerciseName: String, nextSetNum: Int, isPrep: Bool) {
        self.endTime = endTime
        self.totalSeconds = totalSeconds
        self.nextExerciseName = nextExerciseName
        self.nextSetNum = nextSetNum
        self.isPrep = isPrep
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

    init(name: String, startTime: Int64, exercises: [WatchActiveExercise], currentExerciseIndex: Int, elapsedSeconds: Int, paused: Bool, restTimer: WatchRestTimer?, postponed: Bool) {
        self.name = name
        self.startTime = startTime
        self.exercises = exercises
        self.currentExerciseIndex = currentExerciseIndex
        self.elapsedSeconds = elapsedSeconds
        self.paused = paused
        self.restTimer = restTimer
        self.postponed = postponed
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

    init(name: String, muscle: String, sets: Int, reps: Int, rest: Int, weight: Double, setsState: [Bool], measurementType: String, executionType: String?, performedCardios: [WatchPerformedCardio?], failureReport: [Bool], failureReps: [Int?]) {
        self.name = name
        self.muscle = muscle
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.weight = weight
        self.setsState = setsState
        self.measurementType = measurementType
        self.executionType = executionType
        self.performedCardios = performedCardios
        self.failureReport = failureReport
        self.failureReps = failureReps
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

// MARK: - Streak Model

struct WatchStreak: Codable {
    let currentWeekCount: Int
    let consecutiveWeeks: Int
    let lastWorkoutDate: String
    let weekdaysTrained: [Int]
    let completedTodayRoutines: [String]

    enum CodingKeys: String, CodingKey {
        case currentWeekCount, consecutiveWeeks, lastWorkoutDate, weekdaysTrained, completedTodayRoutines
    }

    init(currentWeekCount: Int, consecutiveWeeks: Int, lastWorkoutDate: String, weekdaysTrained: [Int] = [], completedTodayRoutines: [String] = []) {
        self.currentWeekCount = currentWeekCount
        self.consecutiveWeeks = consecutiveWeeks
        self.lastWorkoutDate = lastWorkoutDate
        self.weekdaysTrained = weekdaysTrained
        self.completedTodayRoutines = completedTodayRoutines
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentWeekCount = (try? container.decode(Int.self, forKey: .currentWeekCount)) ?? 0
        consecutiveWeeks = (try? container.decode(Int.self, forKey: .consecutiveWeeks)) ?? 0
        lastWorkoutDate = (try? container.decode(String.self, forKey: .lastWorkoutDate)) ?? ""
        weekdaysTrained = (try? container.decode([Int].self, forKey: .weekdaysTrained)) ?? []
        completedTodayRoutines = (try? container.decode([String].self, forKey: .completedTodayRoutines)) ?? []
    }
}
