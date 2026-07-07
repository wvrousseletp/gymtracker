import ClockKit
import WidgetKit
import SwiftUI
import os.log

struct WatchComplicationProvider: TimelineProvider {
    typealias Entry = ComplicationEntry
    
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), waterProgress: 0.5, streak: 0, nextWorkout: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let cache = WatchDataCache.shared
        let waterCurrent = cache.getWaterIntakeCurrent()
        let waterTarget = cache.getWaterIntakeTarget()
        let waterProgress = waterTarget > 0 ? Double(waterCurrent) / Double(waterTarget) : 0.0
        let streak = cache.getStreak()
        
        let entry = ComplicationEntry(
            date: Date(),
            waterProgress: waterProgress,
            streak: streak.consecutiveWeeks,
            nextWorkout: getNextWorkout()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let cache = WatchDataCache.shared
        let waterCurrent = cache.getWaterIntakeCurrent()
        let waterTarget = cache.getWaterIntakeTarget()
        let waterProgress = waterTarget > 0 ? Double(waterCurrent) / Double(waterTarget) : 0.0
        let streak = cache.getStreak()
        
        let entry = ComplicationEntry(
            date: Date(),
            waterProgress: waterProgress,
            streak: streak.consecutiveWeeks,
            nextWorkout: getNextWorkout()
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getNextWorkout() -> String? {
        // Simplified version - just return nil for now
        // Full implementation would require WatchPlannerHelper
        return nil
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let waterProgress: Double
    let streak: Int
    let nextWorkout: String?
}

struct WatchComplicationView: View {
    let entry: ComplicationEntry
    let family: WidgetFamily
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        default:
            Text("Not supported")
        }
    }
    
    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: entry.waterProgress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: entry.waterProgress)
            
            if entry.waterProgress >= 1.0 {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            } else {
                Text("\(Int(entry.waterProgress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text("Água")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int(entry.waterProgress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: entry.waterProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("Streak")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(entry.streak) semanas")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            if let nextWorkout = entry.nextWorkout {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text(nextWorkout)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var cornerView: some View {
        VStack(spacing: 1) {
            Image(systemName: "drop.fill")
                .font(.system(size: 8))
                .foregroundColor(.blue)
            Text("\(Int(entry.waterProgress * 100))%")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

struct WatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        ComplicationProvider()
    }
}

struct ComplicationProvider: Widget {
    let kind: String = "WatchComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchComplicationView(entry: entry, family: .accessoryCircular)
        }
        .configurationDisplayName("Gym Tracker")
        .description("Mostra progresso de água, streak e próximo treino")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}
