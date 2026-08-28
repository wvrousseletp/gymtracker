import WidgetKit
import SwiftUI

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), activeWorkout: nil, streak: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = loadComplicationData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = loadComplicationData()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func loadComplicationData() -> ComplicationEntry {
        let defaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        
        var active: WatchActiveWorkoutState? = nil
        if let savedData = defaults.data(forKey: "local_workout_state"),
           let decoded = try? JSONDecoder().decode(WatchActiveWorkoutState.self, from: savedData) {
            active = decoded
        }
        
        var streak: WatchStreak? = nil
        if let streakJson = defaults.string(forKey: "cached_streak"),
           let jsonData = streakJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(WatchStreak.self, from: jsonData) {
            streak = decoded
        }
        
        return ComplicationEntry(date: Date(), activeWorkout: active, streak: streak)
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let activeWorkout: WatchActiveWorkoutState?
    let streak: WatchStreak?
}

struct WatchComplicationsEntryView : View {
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

// MARK: - Circular View
struct CircularComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let active = entry.activeWorkout {
                let completed = active.completedSets
                let total = active.totalSets
                let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(completed)/\(total)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
            } else {
                let current = entry.streak?.currentWeekCount ?? 0
                let goal = entry.streak?.weeklyGoal ?? (entry.streak?.weekdaysTrained.count ?? 0 > 0 ? max(entry.streak!.weekdaysTrained.count, 3) : 3)
                let actualGoal = goal > 0 ? goal : 1
                let progress = min(Double(current) / Double(actualGoal), 1.0)
                let freezes = entry.streak?.availableFreezes ?? 0

                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(progress >= 1.0 ? Color.yellow : Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Image(systemName: progress >= 1.0 ? "star.fill" : (freezes > 0 ? "snowflake" : "flame.fill"))
                            .font(.system(size: 10))
                            .foregroundColor(progress >= 1.0 ? .yellow : (freezes > 0 ? .cyan : .orange))
                        Text("\(entry.streak?.consecutiveWeeks ?? 0)")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
            }
        }
    }
}

// MARK: - Corner View
struct CornerComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        if let active = entry.activeWorkout {
            ZStack {
                Text("\(active.completedSets)/\(active.totalSets)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
                    .widgetLabel {
                        Text(active.exerciseName)
                            .foregroundColor(.orange)
                    }
            }
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundColor(.orange)
                .widgetLabel {
                    Text("Streak: \(entry.streak?.consecutiveWeeks ?? 0) sem")
                        .foregroundColor(.orange)
                }
        }
    }
}

// MARK: - Rectangular View
struct RectangularComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let active = entry.activeWorkout {
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(active.routineName)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                Text(active.exerciseName)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                HStack {
                    Text("Série \(active.currentSetIndex + 1)/\(active.totalSets)")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Spacer()
                    if active.isPaused {
                        Text("Pausado")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Los Mooscles")
                        .font(.system(size: 11, weight: .bold))
                }
                Text("Sem treino ativo")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text("Semana: \(entry.streak?.currentWeekCount ?? 0) treinos • Streak: \(entry.streak?.consecutiveWeeks ?? 0)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Inline View
struct InlineComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        if let active = entry.activeWorkout {
            Text("💪 \(active.exerciseName) • \(active.completedSets)/\(active.totalSets)")
        } else {
            Text("🔥 Streak: \(entry.streak?.consecutiveWeeks ?? 0) sem (\(entry.streak?.currentWeekCount ?? 0)x)")
        }
    }
}

// MARK: - Water Complication Implementation

struct WaterComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterComplicationEntry {
        WaterComplicationEntry(date: Date(), current: 1200, target: 2000)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterComplicationEntry) -> Void) {
        let entry = loadWaterData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterComplicationEntry>) -> Void) {
        let entry = loadWaterData()
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWaterData() -> WaterComplicationEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        let standardDefaults = UserDefaults.standard
        
        // 1. Try reading current water intake from App Group
        var current = sharedDefaults?.integer(forKey: "waterIntakeCurrent") ?? 0
        if current == 0 {
            current = sharedDefaults?.integer(forKey: "cached_water_intake") ?? 0
        }
        
        // 2. Fallback to Standard Local defaults (crucial on watchOS if app groups are restricted/delayed)
        if current == 0 {
            current = standardDefaults.integer(forKey: "waterIntakeCurrent")
        }
        if current == 0 {
            current = standardDefaults.integer(forKey: "cached_water_intake")
        }
        
        // 3. Try reading target goal from App Group
        var target = sharedDefaults?.integer(forKey: "waterIntakeTarget") ?? 0
        if target == 0 {
            target = sharedDefaults?.integer(forKey: "cached_water_target") ?? 0
        }
        
        // 4. Fallback target to Standard Local defaults
        if target == 0 {
            target = standardDefaults.integer(forKey: "waterIntakeTarget")
        }
        if target == 0 {
            target = standardDefaults.integer(forKey: "cached_water_target")
        }
        
        // 5. Default backup target if everything is missing
        if target == 0 {
            target = 2000
        }
        
        return WaterComplicationEntry(date: Date(), current: current, target: target)
    }
}

struct WaterComplicationEntry: TimelineEntry {
    let date: Date
    let current: Int
    let target: Int
}

struct WatchWaterComplicationsEntryView : View {
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
                    .foregroundColor(.blue)
            }
        }
        .widgetURL(URL(string: "losmooscles://water"))
    }
}

struct CircularWaterComplicationView: View {
    let entry: WaterComplicationEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            let progress = entry.target > 0 ? Double(entry.current) / Double(entry.target) : 0.0
            
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                    Text("\(entry.current)")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

struct CornerWaterComplicationView: View {
    let entry: WaterComplicationEntry
    
    var body: some View {
        let percent = entry.target > 0 ? Double(entry.current) / Double(entry.target) : 0.0
        
        Image(systemName: "drop.fill")
            .foregroundColor(.blue)
            .widgetLabel {
                ProgressView(value: min(percent, 1.0)) {
                    Text("\(entry.current)ml")
                        .foregroundColor(.blue)
                }
            }
    }
}

struct RectangularWaterComplicationView: View {
    let entry: WaterComplicationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 11))
                Text("Água")
                    .font(.system(size: 11, weight: .bold))
            }
            Text("\(entry.current)ml de \(entry.target)ml")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
            
            let progress = entry.target > 0 ? Double(entry.current) / Double(entry.target) : 0.0
            ProgressView(value: min(progress, 1.0))
                .tint(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineWaterComplicationView: View {
    let entry: WaterComplicationEntry
    
    var body: some View {
        Text("💧 \(entry.current) / \(entry.target)ml")
    }
}

// MARK: - Today's Workout Complication

struct TodayWorkoutComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWorkoutEntry {
        TodayWorkoutEntry(date: Date(), routineName: "Treino de Hoje", exerciseCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWorkoutEntry) -> Void) {
        let entry = loadTodayWorkoutData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWorkoutEntry>) -> Void) {
        let entry = loadTodayWorkoutData()
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadTodayWorkoutData() -> TodayWorkoutEntry {
        let defaults = UserDefaults(suiteName: "group.com.vicente.losmooscles") ?? UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: today)
        
        // Get today's routine IDs from planner
        var routineName = "Sem treino"
        var exerciseCount = 0
        
        if let plannerJson = defaults.string(forKey: "cached_planner"),
           let jsonData = plannerJson.data(using: .utf8),
           let planner = try? JSONDecoder().decode([String: [String]].self, from: jsonData),
           let routineIds = planner[todayStr] {
            
            // Get routines
            if let routinesJson = defaults.string(forKey: "cached_routines"),
               let routinesData = routinesJson.data(using: .utf8),
               let routines = try? JSONDecoder().decode([WatchRoutine].self, from: routinesData) {
                
                let todayRoutines = routines.filter { routine in
                    routineIds.contains(routine.id)
                }
                
                if let firstRoutine = todayRoutines.first {
                    routineName = firstRoutine.name
                    exerciseCount = firstRoutine.exercises.count
                }
            }
        }
        
        return TodayWorkoutEntry(date: Date(), routineName: routineName, exerciseCount: exerciseCount)
    }
}

struct TodayWorkoutEntry: TimelineEntry {
    let date: Date
    let routineName: String
    let exerciseCount: Int
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
            VStack(spacing: 0) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("\(entry.exerciseCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct CornerTodayWorkoutView: View {
    let entry: TodayWorkoutEntry
    
    var body: some View {
        Image(systemName: "calendar")
            .foregroundColor(.green)
            .widgetLabel {
                Text(entry.routineName)
                    .foregroundColor(.green)
            }
    }
}

struct RectangularTodayWorkoutView: View {
    let entry: TodayWorkoutEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Treino de Hoje")
                    .font(.system(size: 11, weight: .bold))
            }
            Text(entry.routineName)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            HStack {
                Text("\(entry.exerciseCount) exercícios")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineTodayWorkoutView: View {
    let entry: TodayWorkoutEntry
    
    var body: some View {
        Text("📅 \(entry.routineName) • \(entry.exerciseCount) ex")
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
        .description("Acompanhe seus treinos e metas semanais.")
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
        .description("Acompanhe sua ingestão de água diária.")
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
