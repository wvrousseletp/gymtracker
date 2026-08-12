import Foundation

struct PlannedWatchItem: Identifiable {
    enum Kind {
        case routine
        case singleExercise
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let routineId: String?
    let exerciseId: String?
}

enum WatchPlannerHelper {
    static func todayPlannerKey(for date: Date = Date()) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
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

    static func resolveTodayPlannedItems(
        routines: [WatchRoutine],
        library: [WatchLibraryExercise],
        planner: [String: [String]],
        date: Date = Date()
    ) -> [PlannedWatchItem] {
        guard let plannedIds = planner[todayPlannerKey(for: date)] else { return [] }

        var items: [PlannedWatchItem] = []
        for raw in plannedIds where !raw.isEmpty {
            if raw.hasPrefix("exercise:") {
                let parts = raw.split(separator: ":").map(String.init)
                guard parts.count >= 2 else { continue }
                let exerciseId = parts[1]
                let sets = parts.count >= 3 ? Int(parts[2]) ?? 3 : 3
                guard let libEx = library.first(where: { $0.id == exerciseId }) else { continue }
                let isCardio = libEx.isCardio
                items.append(
                    PlannedWatchItem(
                        id: "planned-ex-\(exerciseId)-\(sets)",
                        kind: .singleExercise,
                        title: "\(libEx.name) (Avulso)",
                        subtitle: isCardio ? "Cardio planejado" : "\(sets) séries",
                        routineId: nil,
                        exerciseId: exerciseId
                    )
                )
            } else {
                let routineId = raw.hasPrefix("routine:") ? String(raw.dropFirst("routine:".count)) : raw
                guard let routine = routines.first(where: { $0.id == routineId }) else { continue }
                items.append(
                    PlannedWatchItem(
                        id: "planned-routine-\(routine.id)",
                        kind: .routine,
                        title: routine.name,
                        subtitle: "\(routine.exercises.count) exercícios",
                        routineId: routine.id,
                        exerciseId: nil
                    )
                )
            }
        }
        return items
    }

    /// Library entries referenced in today's planner + a capped list of others.
    static func filteredLibraryForWatch(
        library: [WatchLibraryExercise],
        planner: [String: [String]],
        limit: Int = 12
    ) -> [WatchLibraryExercise] {
        let todayItems = resolveTodayPlannedItems(routines: [], library: library, planner: planner)
        var ids = Set<String>()
        for item in todayItems {
            if let exerciseId = item.exerciseId {
                ids.insert(exerciseId)
            }
        }

        let planned = library.filter { ids.contains($0.id) }
        let remaining = library.filter { !ids.contains($0.id) }
        if planned.count >= limit {
            return Array(planned.prefix(limit))
        }
        return planned + Array(remaining.prefix(max(0, limit - planned.count)))
    }
}
