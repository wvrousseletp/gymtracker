import WidgetKit
import SwiftUI

// MARK: - Shared Widget Data Loader

private struct TodayPlanSummary {
    let primaryName: String
    let exerciseCount: Int
    let extraRoutinesCount: Int
    let hasPlannedWorkout: Bool
    let isCompletedToday: Bool
}

private enum WatchWidgetDataLoader {
    static let suiteName = "group.com.vicente.losmooscles"
    private static let staleWorkoutMaxAgeMs: Int64 = 12 * 3600 * 1000 // 12 hours

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    static func todayDateString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func todayWeekdayKey(for date: Date = Date()) -> String {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "dom"
        case 2: return "seg"
        case 3: return "ter"
        case 4: return "qua"
        case 5: return "qui"
        case 6: return "sex"
        case 7: return "sab"
        default: return "seg"
        }
    }

    static func loadActiveWorkout(now: Date = Date()) -> WatchActiveWorkoutState? {
        guard let savedData = sharedDefaults.data(forKey: "local_workout_state"),
              let decoded = try? JSONDecoder().decode(WatchActiveWorkoutState.self, from: savedData) else {
            return nil
        }

        // Ignore postponed, empty, or stale (>12h old) workouts so ghost workouts never linger
        if decoded.postponed || decoded.exercises.isEmpty {
            return nil
        }
        if decoded.startTime > 0 {
            let nowMs = Int64(now.timeIntervalSince1970 * 1000)
            if nowMs - decoded.startTime > staleWorkoutMaxAgeMs {
                return nil
            }
        }
        return decoded
    }

    static func loadStreak() -> WatchStreak? {
        guard let streakJson = sharedDefaults.string(forKey: "cached_streak"),
              let jsonData = streakJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(WatchStreak.self, from: jsonData) else {
            return nil
        }
        return decoded
    }

    static func loadTodayPlan(streak: WatchStreak? = nil, now: Date = Date()) -> TodayPlanSummary {
        let resolvedStreak = streak ?? loadStreak()
        let todayStr = todayDateString(for: now)
        let isCompletedToday: Bool = {
            if let s = resolvedStreak {
                if !s.completedTodayRoutines.isEmpty { return true }
                if s.lastWorkoutDate.hasPrefix(todayStr) { return true }
            }
            return false
        }()

        guard let plannerJson = sharedDefaults.string(forKey: "cached_planner"),
              let plannerData = plannerJson.data(using: .utf8),
              let planner = try? JSONDecoder().decode([String: [String]].self, from: plannerData) else {
            return TodayPlanSummary(
                primaryName: "Dia de descanso",
                exerciseCount: 0,
                extraRoutinesCount: 0,
                hasPlannedWorkout: false,
                isCompletedToday: isCompletedToday
            )
        }

        let weekdayKey = todayWeekdayKey(for: now)
        let rawIds = planner[weekdayKey] ?? planner[todayStr] ?? []

        let routines: [WatchRoutine] = {
            guard let json = sharedDefaults.string(forKey: "cached_routines"),
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([WatchRoutine].self, from: data) else {
                return []
            }
            return decoded
        }()

        let library: [WatchLibraryExercise] = {
            guard let json = sharedDefaults.string(forKey: "cached_library"),
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([WatchLibraryExercise].self, from: data) else {
                return []
            }
            return decoded
        }()

        var resolvedItems: [(name: String, count: Int)] = []
        for raw in rawIds where !raw.isEmpty {
            if raw.hasPrefix("exercise:") {
                let parts = raw.split(separator: ":").map(String.init)
                guard parts.count >= 2 else { continue }
                let exId = parts[1]
                if let libEx = library.first(where: { $0.id == exId }) {
                    resolvedItems.append((name: libEx.name, count: 1))
                }
            } else {
                let routineId = raw.hasPrefix("routine:") ? String(raw.dropFirst("routine:".count)) : raw
                if let routine = routines.first(where: { $0.id == routineId }) {
                    resolvedItems.append((name: routine.name, count: routine.exercises.count))
                }
            }
        }

        guard let first = resolvedItems.first else {
            return TodayPlanSummary(
                primaryName: "Dia de descanso",
                exerciseCount: 0,
                extraRoutinesCount: 0,
                hasPlannedWorkout: false,
                isCompletedToday: isCompletedToday
            )
        }

        return TodayPlanSummary(
            primaryName: first.name,
            exerciseCount: first.count,
            extraRoutinesCount: max(0, resolvedItems.count - 1),
            hasPlannedWorkout: true,
            isCompletedToday: isCompletedToday
        )
    }

    static func loadWater(now: Date = Date()) -> (current: Int, target: Int) {
        let shared = UserDefaults(suiteName: suiteName)
        let standard = UserDefaults.standard

        let savedDate = shared?.string(forKey: "cached_water_date") ?? standard.string(forKey: "cached_water_date") ?? ""
        let todayStr = todayDateString(for: now)

        var target = shared?.integer(forKey: "waterIntakeTarget") ?? 0
        if target == 0 { target = shared?.integer(forKey: "cached_water_target") ?? 0 }
        if target == 0 { target = standard.integer(forKey: "waterIntakeTarget") }
        if target == 0 { target = standard.integer(forKey: "cached_water_target") }
        if target == 0 { target = 2000 }

        // Reset to 0 automatically after midnight until the app syncs today's intake
        if !savedDate.isEmpty && savedDate != todayStr {
            return (0, target)
        }

        var current = shared?.integer(forKey: "waterIntakeCurrent") ?? 0
        if current == 0 { current = shared?.integer(forKey: "cached_water_intake") ?? 0 }
        if current == 0 { current = standard.integer(forKey: "waterIntakeCurrent") }
        if current == 0 { current = standard.integer(forKey: "cached_water_intake") }

        return (current, target)
    }

    static func formatWater(_ ml: Int, compact: Bool = false) -> String {
        if ml >= 1000 {
            let liters = Double(ml) / 1000.0
            return liters.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fL", liters)
                : String(format: "%.1fL", liters)
        }
        return compact ? "\(ml)" : "\(ml)ml"
    }

    static func nextMidnight(after date: Date = Date()) -> Date {
        let startOfToday = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(3600)
    }
}

// MARK: - 1. Main Workout & Streak Complication

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(
            date: Date(),
            activeWorkout: nil,
            streak: WatchStreak(currentWeekCount: 3, consecutiveWeeks: 4, lastWorkoutDate: "", weeklyGoal: 4),
            todayPlan: TodayPlanSummary(primaryName: "Treino A", exerciseCount: 6, extraRoutinesCount: 0, hasPlannedWorkout: true, isCompletedToday: false)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(loadComplicationData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let now = Date()
        let entry = loadComplicationData(now: now)
        let refreshMinutes = entry.activeWorkout != nil ? 5 : 30
        let nextInterval = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: now) ?? now.addingTimeInterval(1800)
        let nextUpdate = min(nextInterval, WatchWidgetDataLoader.nextMidnight(after: now))
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadComplicationData(now: Date = Date()) -> ComplicationEntry {
        let active = WatchWidgetDataLoader.loadActiveWorkout(now: now)
        let streak = WatchWidgetDataLoader.loadStreak()
        let todayPlan = WatchWidgetDataLoader.loadTodayPlan(streak: streak, now: now)
        return ComplicationEntry(date: now, activeWorkout: active, streak: streak, todayPlan: todayPlan)
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let activeWorkout: WatchActiveWorkoutState?
    let streak: WatchStreak?
    fileprivate let todayPlan: TodayPlanSummary

    var workoutCompletedSets: Int {
        guard let active = activeWorkout else { return 0 }
        return active.exercises.reduce(0) { $0 + $1.setsState.filter { $0 }.count }
    }

    var workoutTotalSets: Int {
        guard let active = activeWorkout else { return 0 }
        return active.exercises.reduce(0) { $0 + max($1.sets, $1.setsState.count) }
    }

    var weeklyCurrent: Int { streak?.currentWeekCount ?? 0 }

    var weeklyGoal: Int {
        if let goal = streak?.weeklyGoal, goal > 0 { return goal }
        let trained = streak?.weekdaysTrained.count ?? 0
        return trained > 0 ? max(trained, 3) : 3
    }

    var consecutiveWeeks: Int { streak?.consecutiveWeeks ?? 0 }
}

struct WatchComplicationsEntryView: View {
    var entry: ComplicationProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularComplicationView(entry: entry)
            case .accessoryCorner:
                CornerComplicationView(entry: entry)
            case .accessoryRectangular:
                RectangularComplicationView(entry: entry)
            case .accessoryInline:
                InlineComplicationView(entry: entry)
            default:
                Text("💪")
            }
        }
        .widgetURL(URL(string: "losmooscles://workouts"))
    }
}

// MARK: Circular View
struct CircularComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let active = entry.activeWorkout {
                let completed = entry.workoutCompletedSets
                let total = max(entry.workoutTotalSets, 1)
                let progress = min(Double(completed) / Double(total), 1.0)
                let accent: Color = active.isPaused ? .yellow : .green

                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.22), lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Image(systemName: active.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(accent)
                        Text("\(completed)/\(total)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(2)
            } else {
                let progress = min(Double(entry.weeklyCurrent) / Double(max(entry.weeklyGoal, 1)), 1.0)
                let goalMet = progress >= 1.0
                let freezes = entry.streak?.availableFreezes ?? 0
                let ringColor: Color = goalMet ? .yellow : .orange

                ZStack {
                    Circle()
                        .stroke(ringColor.opacity(0.22), lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Image(systemName: goalMet ? "star.fill" : (freezes > 0 ? "snowflake" : "flame.fill"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(goalMet ? .yellow : (freezes > 0 ? .cyan : .orange))
                        Text("\(entry.consecutiveWeeks)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                }
                .padding(2)
            }
        }
    }
}

// MARK: Corner View
struct CornerComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        if let active = entry.activeWorkout {
            let completed = entry.workoutCompletedSets
            let total = max(entry.workoutTotalSets, 1)
            let progress = min(Double(completed) / Double(total), 1.0)

            Image(systemName: active.isPaused ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(active.isPaused ? .yellow : .green)
                .widgetLabel {
                    ProgressView(value: progress) {
                        Text("\(completed)/\(total)")
                    }
                    .tint(active.isPaused ? .yellow : .green)
                }
        } else {
            let progress = min(Double(entry.weeklyCurrent) / Double(max(entry.weeklyGoal, 1)), 1.0)
            Image(systemName: progress >= 1.0 ? "star.fill" : "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(progress >= 1.0 ? .yellow : .orange)
                .widgetLabel {
                    ProgressView(value: progress) {
                        Text("\(entry.consecutiveWeeks)s • \(entry.weeklyCurrent)/\(entry.weeklyGoal)")
                    }
                    .tint(progress >= 1.0 ? .yellow : .orange)
                }
        }
    }
}

// MARK: Rectangular View
struct RectangularComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let active = entry.activeWorkout {
                let completed = entry.workoutCompletedSets
                let total = max(entry.workoutTotalSets, 1)
                let progress = min(Double(completed) / Double(total), 1.0)

                HStack(spacing: 4) {
                    Image(systemName: active.isPaused ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                        .foregroundColor(active.isPaused ? .yellow : .green)
                        .font(.system(size: 11, weight: .bold))
                    Text(active.routineName)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    Text(active.isPaused ? "PAUSA" : "\(completed)/\(total)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(active.isPaused ? .yellow : .green)
                }

                Text(active.exerciseName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                ProgressView(value: progress)
                    .tint(active.isPaused ? .yellow : .green)
            } else {
                let plan = entry.todayPlan
                HStack(spacing: 4) {
                    Image(systemName: plan.isCompletedToday ? "checkmark.seal.fill" : "flame.fill")
                        .foregroundColor(plan.isCompletedToday ? .green : .orange)
                        .font(.system(size: 11, weight: .bold))
                    Text(plan.isCompletedToday ? "Treino feito!" : (plan.hasPlannedWorkout ? plan.primaryName : "Los Mooscles"))
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.consecutiveWeeks)s")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                }

                Text(plan.isCompletedToday
                     ? "Meta semanal: \(entry.weeklyCurrent)/\(entry.weeklyGoal) treinos"
                     : (plan.hasPlannedWorkout
                        ? "Hoje • \(plan.exerciseCount) exercícios"
                        : "Dia de descanso"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(1)

                let weekProgress = min(Double(entry.weeklyCurrent) / Double(max(entry.weeklyGoal, 1)), 1.0)
                ProgressView(value: weekProgress)
                    .tint(weekProgress >= 1.0 ? .yellow : .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Inline View
struct InlineComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        if let active = entry.activeWorkout {
            Text("💪 \(active.exerciseName) • \(entry.workoutCompletedSets)/\(entry.workoutTotalSets)")
        } else {
            Text("🔥 \(entry.consecutiveWeeks) sem • \(entry.weeklyCurrent)/\(entry.weeklyGoal) treinos")
        }
    }
}

// MARK: - 2. Water Complication

struct WaterComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterComplicationEntry {
        WaterComplicationEntry(date: Date(), current: 1500, target: 2500)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterComplicationEntry) -> Void) {
        completion(loadWaterData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterComplicationEntry>) -> Void) {
        let now = Date()
        let entry = loadWaterData(now: now)
        let nextInterval = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let nextUpdate = min(nextInterval, WatchWidgetDataLoader.nextMidnight(after: now))
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWaterData(now: Date = Date()) -> WaterComplicationEntry {
        let water = WatchWidgetDataLoader.loadWater(now: now)
        return WaterComplicationEntry(date: now, current: water.current, target: water.target)
    }
}

struct WaterComplicationEntry: TimelineEntry {
    let date: Date
    let current: Int
    let target: Int

    var progress: Double {
        target > 0 ? min(Double(current) / Double(target), 1.0) : 0.0
    }

    var percentInt: Int {
        target > 0 ? Int(round((Double(current) / Double(target)) * 100.0)) : 0
    }

    var isGoalMet: Bool {
        target > 0 && current >= target
    }
}

struct WatchWaterComplicationsEntryView: View {
    var entry: WaterComplicationProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularWaterComplicationView(entry: entry)
            case .accessoryCorner:
                CornerWaterComplicationView(entry: entry)
            case .accessoryRectangular:
                RectangularWaterComplicationView(entry: entry)
            case .accessoryInline:
                InlineWaterComplicationView(entry: entry)
            default:
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
            }
        }
        .widgetURL(URL(string: "losmooscles://water"))
    }
}

struct CircularWaterComplicationView: View {
    let entry: WaterComplicationEntry

    var body: some View {
        let accent: Color = entry.isGoalMet ? .green : .cyan
        ZStack {
            AccessoryWidgetBackground()
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.22), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.progress))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Image(systemName: entry.isGoalMet ? "checkmark" : "drop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(accent)
                    Text(WatchWidgetDataLoader.formatWater(entry.current, compact: true))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(2)
        }
    }
}

struct CornerWaterComplicationView: View {
    let entry: WaterComplicationEntry

    var body: some View {
        let accent: Color = entry.isGoalMet ? .green : .cyan
        Image(systemName: entry.isGoalMet ? "checkmark.circle.fill" : "drop.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(accent)
            .widgetLabel {
                ProgressView(value: entry.progress) {
                    Text(WatchWidgetDataLoader.formatWater(entry.current))
                }
                .tint(accent)
            }
    }
}

struct RectangularWaterComplicationView: View {
    let entry: WaterComplicationEntry

    var body: some View {
        let accent: Color = entry.isGoalMet ? .green : .cyan
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: entry.isGoalMet ? "checkmark.circle.fill" : "drop.fill")
                    .foregroundColor(accent)
                    .font(.system(size: 11, weight: .bold))
                Text("Hidratação")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(entry.percentInt)%")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(accent)
            }

            Text("\(WatchWidgetDataLoader.formatWater(entry.current)) de \(WatchWidgetDataLoader.formatWater(entry.target))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            ProgressView(value: entry.progress)
                .tint(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineWaterComplicationView: View {
    let entry: WaterComplicationEntry

    var body: some View {
        if entry.isGoalMet {
            Text("✅ Água: \(WatchWidgetDataLoader.formatWater(entry.current))")
        } else {
            Text("💧 \(WatchWidgetDataLoader.formatWater(entry.current)) / \(WatchWidgetDataLoader.formatWater(entry.target))")
        }
    }
}

// MARK: - 3. Today's Workout Complication

struct TodayWorkoutComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWorkoutEntry {
        TodayWorkoutEntry(
            date: Date(),
            routineName: "Treino A",
            exerciseCount: 6,
            extraRoutinesCount: 0,
            hasPlannedWorkout: true,
            isCompletedToday: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWorkoutEntry) -> Void) {
        completion(loadTodayWorkoutData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWorkoutEntry>) -> Void) {
        let now = Date()
        let entry = loadTodayWorkoutData(now: now)
        let nextInterval = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        let nextUpdate = min(nextInterval, WatchWidgetDataLoader.nextMidnight(after: now))
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadTodayWorkoutData(now: Date = Date()) -> TodayWorkoutEntry {
        let plan = WatchWidgetDataLoader.loadTodayPlan(now: now)
        return TodayWorkoutEntry(
            date: now,
            routineName: plan.primaryName,
            exerciseCount: plan.exerciseCount,
            extraRoutinesCount: plan.extraRoutinesCount,
            hasPlannedWorkout: plan.hasPlannedWorkout,
            isCompletedToday: plan.isCompletedToday
        )
    }
}

struct TodayWorkoutEntry: TimelineEntry {
    let date: Date
    let routineName: String
    let exerciseCount: Int
    let extraRoutinesCount: Int
    let hasPlannedWorkout: Bool
    let isCompletedToday: Bool
}

struct TodayWorkoutComplicationEntryView: View {
    var entry: TodayWorkoutComplicationProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularTodayWorkoutView(entry: entry)
            case .accessoryCorner:
                CornerTodayWorkoutView(entry: entry)
            case .accessoryRectangular:
                RectangularTodayWorkoutView(entry: entry)
            case .accessoryInline:
                InlineTodayWorkoutView(entry: entry)
            default:
                Text("💪")
            }
        }
        .widgetURL(URL(string: "losmooscles://workouts"))
    }
}

struct CircularTodayWorkoutView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isCompletedToday {
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    Text("FEITO")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.green)
                }
            } else if entry.hasPlannedWorkout {
                VStack(spacing: 0) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                    Text("\(entry.exerciseCount) ex")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    Text("OFF")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

struct CornerTodayWorkoutView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        let icon = entry.isCompletedToday
            ? "checkmark.seal.fill"
            : (entry.hasPlannedWorkout ? "figure.strengthtraining.traditional" : "moon.zzz.fill")
        let color: Color = entry.isCompletedToday ? .green : (entry.hasPlannedWorkout ? .green : .blue)
        let label = entry.isCompletedToday
            ? "Treino feito!"
            : (entry.hasPlannedWorkout ? entry.routineName : "Descanso")

        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(color)
            .widgetLabel {
                Text(label)
                    .foregroundColor(color)
            }
    }
}

struct RectangularTodayWorkoutView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: entry.isCompletedToday ? "checkmark.seal.fill" : (entry.hasPlannedWorkout ? "calendar" : "moon.zzz.fill"))
                    .foregroundColor(entry.hasPlannedWorkout || entry.isCompletedToday ? .green : .blue)
                    .font(.system(size: 11, weight: .bold))
                Text(entry.isCompletedToday ? "Feito Hoje" : "Treino de Hoje")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(entry.isCompletedToday ? .green : .white)
                Spacer()
                if entry.extraRoutinesCount > 0 {
                    Text("+\(entry.extraRoutinesCount)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                }
            }

            Text(entry.routineName)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)

            if entry.isCompletedToday {
                Text("Treino concluído ✓")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
            } else if entry.hasPlannedWorkout {
                Text("\(entry.exerciseCount) \(entry.exerciseCount == 1 ? "exercício" : "exercícios")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
            } else {
                Text("Aproveite para recuperar")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineTodayWorkoutView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        if entry.isCompletedToday {
            Text("✅ Treino de hoje feito!")
        } else if entry.hasPlannedWorkout {
            Text("📅 \(entry.routineName) • \(entry.exerciseCount) ex")
        } else {
            Text("😴 Dia de descanso")
        }
    }
}

// MARK: - Widgets Configurations

struct WatchComplications: Widget {
    let kind: String = "WatchComplications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            WatchComplicationsEntryView(entry: entry)
        }
        .configurationDisplayName("Treino Los Mooscles")
        .description("Acompanhe seu treino ativo, streak e meta semanal.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchWaterComplication: Widget {
    let kind: String = "WatchWaterComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterComplicationProvider()) { entry in
            WatchWaterComplicationsEntryView(entry: entry)
        }
        .configurationDisplayName("Água Los Mooscles")
        .description("Acompanhe sua hidratação diária.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWorkoutComplication: Widget {
    let kind: String = "TodayWorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWorkoutComplicationProvider()) { entry in
            TodayWorkoutComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Treino de Hoje")
        .description("Veja o treino programado para hoje.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchComplications()
        WatchWaterComplication()
        TodayWorkoutComplication()
    }
}
