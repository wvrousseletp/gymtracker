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
        let defaults = UserDefaults.standard
        
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
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("\(entry.streak?.consecutiveWeeks ?? 0)")
                        .font(.system(size: 9, weight: .bold))
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

struct WatchComplications: Widget {
    let kind: String = "WatchComplications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            WatchComplicationsEntryView(entry: entry)
        }
        .configurationDisplayName("Los Mooscles")
        .description("Acompanhe seus treinos e metas semanais.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
