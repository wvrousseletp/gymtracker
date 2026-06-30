import Foundation
import WatchConnectivity
import Combine
import os.log
import WidgetKit
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
    @Published var waterIntakeCurrent: Int = 0
    @Published var waterIntakeTarget: Int = 2000
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
            }
        }
    }

    private var session: WCSession?
    private var pendingHandoffToPhone = false
    private let pendingOfflineCacheKey = "pending_offline_workout_cache"

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
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        self.waterIntakeCurrent = sharedDefaults.integer(forKey: "cached_water_intake")
        let cachedTarget = sharedDefaults.integer(forKey: "cached_water_target")
        self.waterIntakeTarget = cachedTarget > 0 ? cachedTarget : 2000
        
        checkAndResetDailyWater()
        
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
                    WatchLogger.connectivity.info("Reconnected with local workout '\(active.name)' — handoff to iPhone")
                    self.pendingHandoffToPhone = true
                    session.transferUserInfo([
                        "action": "updateActiveWorkout",
                        "activeWorkout": json
                    ])
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
                    WatchLogger.connectivity.error("Error decoding routines: \(error.localizedDescription)")
                }
            }

            // 2. Process library
            if let jsonString = data["library"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                    UserDefaults.standard.set(jsonString, forKey: "cached_library")
                } catch {
                    WatchLogger.connectivity.error("Error decoding library: \(error.localizedDescription)")
                }
            }

            // 2.1 Process planner
            if let jsonString = data["planner"] as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                    UserDefaults.standard.set(jsonString, forKey: "cached_planner")
                } catch {
                    WatchLogger.connectivity.error("Error decoding planner: \(error.localizedDescription)")
                }
            }

            // 2.2 Process water
            let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
            if let waterIntakeCurrent = data["waterIntakeCurrent"] as? Int {
                self.waterIntakeCurrent = waterIntakeCurrent
                sharedDefaults.set(waterIntakeCurrent, forKey: "cached_water_intake")
                UserDefaults.standard.set(waterIntakeCurrent, forKey: "cached_water_intake")
            }
            if let waterIntakeTarget = data["waterIntakeTarget"] as? Int {
                self.waterIntakeTarget = waterIntakeTarget
                sharedDefaults.set(waterIntakeTarget, forKey: "cached_water_target")
                UserDefaults.standard.set(waterIntakeTarget, forKey: "cached_water_target")
            }
            if let waterIntakeDate = data["waterIntakeDate"] as? String {
                sharedDefaults.set(waterIntakeDate, forKey: "cached_water_date")
                UserDefaults.standard.set(waterIntakeDate, forKey: "cached_water_date")
            }
            WidgetCenter.shared.reloadAllTimelines()

            let oldWorkout = self.activeWorkout
            var receivedActiveWorkout = false

            // 3. Process active workout / clear active workout
            if !self.isLocalWorkout || self.pendingHandoffToPhone {
                if let jsonString = data["activeWorkout"] as? String,
                   let jsonData = jsonString.data(using: .utf8) {
                    do {
                        self.activeWorkout = try JSONDecoder().decode(WatchActiveWorkoutState.self, from: jsonData)
                        receivedActiveWorkout = true
                        if self.pendingHandoffToPhone {
                            self.pendingHandoffToPhone = false
                            self.isLocalWorkout = false
                        }
                    } catch {
                        WatchLogger.connectivity.error("Error decoding active workout: \(error.localizedDescription)")
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
                            WatchLogger.connectivity.error("Error decoding routines in action: \(error.localizedDescription)")
                        }
                    }
                case "updateLibrary":
                    if let jsonString = data["library"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.library = try JSONDecoder().decode([WatchLibraryExercise].self, from: jsonData)
                            UserDefaults.standard.set(jsonString, forKey: "cached_library")
                        } catch {
                            WatchLogger.connectivity.error("Error decoding library in action: \(error.localizedDescription)")
                        }
                    }
                case "updatePlanner":
                    if let jsonString = data["planner"] as? String,
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            self.planner = try JSONDecoder().decode([String: [String]].self, from: jsonData)
                            UserDefaults.standard.set(jsonString, forKey: "cached_planner")
                        } catch {
                            WatchLogger.connectivity.error("Error decoding planner in action: \(error.localizedDescription)")
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
                                WatchLogger.connectivity.error("Error decoding active workout in action: \(error.localizedDescription)")
                            }
                        }
                    }
                case "updateWater":
                    let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
                    if let current = data["waterIntakeCurrent"] as? Int {
                        self.waterIntakeCurrent = current
                        sharedDefaults.set(current, forKey: "cached_water_intake")
                        UserDefaults.standard.set(current, forKey: "cached_water_intake")
                    }
                    if let target = data["waterIntakeTarget"] as? Int {
                        self.waterIntakeTarget = target
                        sharedDefaults.set(target, forKey: "cached_water_target")
                        UserDefaults.standard.set(target, forKey: "cached_water_target")
                    }
                    if let date = data["waterIntakeDate"] as? String {
                        sharedDefaults.set(date, forKey: "cached_water_date")
                        UserDefaults.standard.set(date, forKey: "cached_water_date")
                    }
                    WidgetCenter.shared.reloadAllTimelines()

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

                case "offlineWorkoutAck":
                    if let workoutId = data["workoutId"] as? String {
                        self.removeAcknowledgedOfflineWorkout(workoutId: workoutId)
                    }

                case "updateStreak":
                    if let streakJson = data["streak"] as? String,
                       let jsonData = streakJson.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(WatchStreak.self, from: jsonData) {
                        self.streak = decoded
                        UserDefaults.standard.set(streakJson, forKey: "cached_streak")
                        WidgetCenter.shared.reloadAllTimelines()
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

    func startWorkout(routineId: String, customExercises: [[String: Any]]? = nil) {
        if isReachable {
            var msg: [String: Any] = [
                "action": "startWorkout",
                "routineId": routineId
            ]
            if let custom = customExercises {
                msg["customExercises"] = custom
            }
            sendToiPhone(msg)
        } else {
            isLocalWorkout = true
            startLocalWorkout(routineId: routineId, customExercises: customExercises)
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

    func completeWorkout(rpe: Int, notes: String) {
        if isLocalWorkout {
            completeLocalWorkout(rpe: rpe, notes: notes)
        } else {
            sendToiPhone([
                "action": "completeWorkout",
                "rpe": rpe,
                "notes": notes
            ])
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

    func updateWaterIntake(newAmountMl: Int) {
        checkAndResetDailyWater()
        self.waterIntakeCurrent = newAmountMl
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        sharedDefaults.set(newAmountMl, forKey: "cached_water_intake")
        UserDefaults.standard.set(newAmountMl, forKey: "cached_water_intake")
        
        WidgetCenter.shared.reloadAllTimelines()
        
        sendToiPhone([
            "action": "updateWaterIntake",
            "waterIntakeMl": newAmountMl
        ])
    }

    private func checkAndResetDailyWater() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: now)
        
        let savedDate = sharedDefaults.string(forKey: "cached_water_date") ?? ""
        if savedDate != todayStr {
            self.waterIntakeCurrent = 0
            sharedDefaults.set(0, forKey: "cached_water_intake")
            sharedDefaults.set(todayStr, forKey: "cached_water_date")
            UserDefaults.standard.set(0, forKey: "cached_water_intake")
            UserDefaults.standard.set(todayStr, forKey: "cached_water_date")
            WidgetCenter.shared.reloadAllTimelines()
        }
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
                WatchLogger.connectivity.warning("sendMessage failed (\(error.localizedDescription)) – retrying via transferUserInfo")
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func startLocalWorkout(routineId: String, customExercises: [[String: Any]]? = nil) {
        guard let routine = routines.first(where: { $0.id == routineId }) else { return }
        
        var activeExercises: [WatchActiveExercise] = []
        for re in routine.exercises {
            let libEx = library.first(where: { $0.id == re.exerciseId })
            let name = libEx?.name ?? "Exercício"
            let muscle = libEx?.muscle ?? "Geral"
            let measurementType = libEx?.measurementType ?? "reps"
            let executionType = libEx?.executionType
            
            var targetSets = re.sets
            var targetReps = re.reps
            var targetWeight = re.weight
            
            if let custom = customExercises?.first(where: { ($0["exerciseId"] as? String) == re.exerciseId }) {
                targetSets = custom["sets"] as? Int ?? re.sets
                targetReps = custom["reps"] as? Int ?? re.reps
                targetWeight = custom["weight"] as? Double ?? re.weight
            }
            
            let activeEx = WatchActiveExercise(
                name: name,
                muscle: muscle,
                sets: targetSets,
                reps: targetReps,
                rest: re.rest,
                weight: targetWeight,
                setsState: Array(repeating: false, count: targetSets),
                measurementType: measurementType,
                executionType: executionType,
                performedCardios: Array(repeating: nil, count: targetSets),
                failureReport: Array(repeating: false, count: targetSets),
                failureReps: Array(repeating: nil, count: targetSets)
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

    private func completeLocalWorkout(rpe: Int = 8, notes: String = "Treino concluído em modo offline via Apple Watch") {
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
                "rpe": rpe,
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
            "rpe": rpe,
            "notes": notes,
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

    private func migrateLegacyOfflineCacheIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.array(forKey: pendingOfflineCacheKey) == nil,
              let legacy = defaults.array(forKey: "offline_workout_cache") as? [[String: Any]],
              !legacy.isEmpty else { return }
        defaults.set(legacy, forKey: pendingOfflineCacheKey)
        defaults.removeObject(forKey: "offline_workout_cache")
    }

    private func saveOfflineWorkoutToCache(_ workout: [String: Any]) {
        migrateLegacyOfflineCacheIfNeeded()
        let defaults = UserDefaults.standard
        var cachedWorkouts = defaults.array(forKey: pendingOfflineCacheKey) as? [[String: Any]] ?? []
        cachedWorkouts.append(workout)
        defaults.set(cachedWorkouts, forKey: pendingOfflineCacheKey)
        WatchLogger.connectivity.info("Saved offline workout \(workout["id"] as? String ?? "unknown") pending sync")
    }

    private func removeAcknowledgedOfflineWorkout(workoutId: String) {
        let defaults = UserDefaults.standard
        guard var cached = defaults.array(forKey: pendingOfflineCacheKey) as? [[String: Any]] else { return }
        let before = cached.count
        cached.removeAll { ($0["id"] as? String) == workoutId }
        if cached.count != before {
            defaults.set(cached, forKey: pendingOfflineCacheKey)
            WatchLogger.connectivity.info("Removed acknowledged offline workout \(workoutId)")
        }
    }

    func syncOfflineWorkouts() {
        migrateLegacyOfflineCacheIfNeeded()
        let defaults = UserDefaults.standard
        guard let cachedWorkouts = defaults.array(forKey: pendingOfflineCacheKey) as? [[String: Any]], !cachedWorkouts.isEmpty else {
            return
        }
        guard let session = session else { return }

        WatchLogger.connectivity.info("Attempting to sync \(cachedWorkouts.count) pending offline workouts")
        for workout in cachedWorkouts {
            guard let workoutId = workout["id"] as? String else { continue }
            let message: [String: Any] = [
                "action": "syncOfflineWorkout",
                "workoutId": workoutId,
                "workoutData": workout
            ]
            session.transferUserInfo(message)
        }
    }
}
