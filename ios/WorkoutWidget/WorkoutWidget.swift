import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Today Routine Widget

struct TodayRoutineEntry: TimelineEntry {
    let date: Date
    let routineName: String
    let exerciseCount: Int
    let exercises: [String]
}

struct TodayRoutineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayRoutineEntry {
        TodayRoutineEntry(date: Date(), routineName: "Peito e Tríceps", exerciseCount: 5, exercises: ["Supino Reto", "Tríceps Pulley", "Crucifixo Inclinado"])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayRoutineEntry) -> ()) {
        let entry = TodayRoutineEntry(date: Date(), routineName: "Peito e Tríceps", exerciseCount: 5, exercises: ["Supino Reto", "Tríceps Pulley", "Crucifixo Inclinado"])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayRoutineEntry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        let routineName = sharedDefaults?.string(forKey: "todayRoutineName") ?? "Nenhum treino planejado"
        let count = sharedDefaults?.integer(forKey: "todayRoutineExerciseCount") ?? 0
        let exercises = sharedDefaults?.stringArray(forKey: "todayRoutineExercises") ?? []
        
        let entry = TodayRoutineEntry(date: Date(), routineName: routineName, exerciseCount: count, exercises: exercises)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct TodayRoutineWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodayRoutineProvider.Entry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("HOJE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                }
                Text(entry.routineName)
                    .font(.system(size: 12, weight: .black))
                    .lineLimit(1)
                Text("\(entry.exerciseCount) Exercícios")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("Treino: \(entry.routineName)")
        case .accessoryCircular:
            Gauge(value: entry.exerciseCount > 0 ? 0.5 : 0.0) {
                Image(systemName: "figure.walk")
                    .foregroundColor(.orange)
            } currentValueLabel: {
                Text("\(entry.exerciseCount)")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: "figure.walk")
                .foregroundColor(.orange)
                .widgetLabel {
                    Text(entry.routineName)
                }
        #endif
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("TREINO DE HOJE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.orange.opacity(0.8))
                    Spacer()
                }
                
                Text(entry.routineName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if entry.exerciseCount > 0 {
                    Text("\(entry.exerciseCount) Exercícios")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(entry.exercises.prefix(3), id: \.self) { ex in
                            Text("• \(ex)")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Spacer()
                    Text("Dia de descanso!")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        }
    }
}

struct TodayRoutineWidget: Widget {
    let kind: String = "TodayRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayRoutineProvider()) { entry in
            TodayRoutineWidgetView(entry: entry)
        }
        .configurationDisplayName("Treino de Hoje")
        .description("Acompanhe seu treino planejado para o dia.")
        .supportedFamilies({
            #if os(watchOS)
            return [
                .accessoryRectangular,
                .accessoryInline,
                .accessoryCircular,
                .accessoryCorner
            ]
            #else
            return [
                .systemSmall,
                .systemMedium,
                .accessoryRectangular,
                .accessoryInline,
                .accessoryCircular
            ]
            #endif
        }())
    }
}

// MARK: - Water Intake Widget

struct WaterIntakeEntry: TimelineEntry {
    let date: Date
    let currentMl: Int
    let targetMl: Int
}

struct WaterIntakeProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterIntakeEntry {
        WaterIntakeEntry(date: Date(), currentMl: 1500, targetMl: 3000)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterIntakeEntry) -> ()) {
        let entry = WaterIntakeEntry(date: Date(), currentMl: 1500, targetMl: 3000)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterIntakeEntry>) -> ()) {
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
        
        let entry = WaterIntakeEntry(date: Date(), currentMl: current, targetMl: target)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct WaterIntakeWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: WaterIntakeProvider.Entry

    var percent: Double {
        entry.targetMl > 0 ? Double(entry.currentMl) / Double(entry.targetMl) : 0.0
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: percent) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(String(format: "%.0f%%", percent * 100))
                    .font(.system(size: 8, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text("Água: \(entry.currentMl)ml")
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("ÁGUA")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.blue.opacity(0.8))
                    Spacer()
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.currentMl) ml")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.blue)
                        Text("Meta: \(entry.targetMl) ml")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    Text(String(format: "%.0f%%", percent * 100))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: min(geometry.size.width * CGFloat(percent), geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
                
                // Interactive buttons for iOS 17+
                #if compiler(>=5.9)
                if #available(iOS 17.0, *) {
                    WaterIntakeButtonsView()
                }
                #endif
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        }
    }
}

#if compiler(>=5.9)
@available(iOS 17.0, *)
struct WaterIntakeButtonsView: View {
    var body: some View {
        HStack(spacing: 6) {
            Button(intent: AddWaterIntent(amount: 250)) {
                Text("+250ml")
                    .font(.system(size: 9, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            Button(intent: AddWaterIntent(amount: 500)) {
                Text("+500ml")
                    .font(.system(size: 9, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}
#endif

struct WaterIntakeWidget: Widget {
    let kind: String = "WaterIntakeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterIntakeProvider()) { entry in
            WaterIntakeWidgetView(entry: entry)
        }
        .configurationDisplayName("Ingestão de Água")
        .description("Monitore seu consumo de água diário.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}
