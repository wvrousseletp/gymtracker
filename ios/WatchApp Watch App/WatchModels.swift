import Foundation

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

    var routineName: String {
        return name
    }

    var exerciseName: String {
        guard currentExerciseIndex >= 0 && currentExerciseIndex < exercises.count else {
            return "Exercício"
        }
        return exercises[currentExerciseIndex].name
    }

    var totalSets: Int {
        guard currentExerciseIndex >= 0 && currentExerciseIndex < exercises.count else {
            return 0
        }
        return exercises[currentExerciseIndex].sets
    }

    var completedSets: Int {
        guard currentExerciseIndex >= 0 && currentExerciseIndex < exercises.count else {
            return 0
        }
        return exercises[currentExerciseIndex].setsState.filter { $0 }.count
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
    let instanceId: String
    var id: String { instanceId }
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
        case instanceId, name, muscle, sets, reps, rest, weight, setsState, measurementType, executionType, performedCardios, failureReport, failureReps
    }

    init(name: String, muscle: String, sets: Int, reps: Int, rest: Int, weight: Double, setsState: [Bool], measurementType: String, executionType: String?, performedCardios: [WatchPerformedCardio?], failureReport: [Bool], failureReps: [Int?], instanceId: String = UUID().uuidString) {
        self.instanceId = instanceId
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
        instanceId = (try? container.decode(String.self, forKey: .instanceId)) ?? UUID().uuidString
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
