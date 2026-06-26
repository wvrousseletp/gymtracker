//
//  WatchApp_Watch_AppTests.swift
//  WatchApp Watch AppTests
//

import XCTest
@testable import WatchApp_Watch_App

final class WatchApp_Watch_AppTests: XCTestCase {

    private func makeTuesday() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 6, day: 23))!
    }

    private func makeLibraryExercise(id: String, name: String, muscle: String) -> WatchLibraryExercise {
        let json = """
        {"id":"\(id)","name":"\(name)","muscle":"\(muscle)","measurementType":"weight"}
        """
        return try! JSONDecoder().decode(WatchLibraryExercise.self, from: Data(json.utf8))
    }

    func testTodayPlannerKeyUsesBrazilianWeekdayKeys() {
        XCTAssertEqual(WatchPlannerHelper.todayPlannerKey(for: makeTuesday()), "ter")
    }

    func testResolveTodayPlannedItemsIncludesExercisePrefix() {
        let library = [makeLibraryExercise(id: "ex1", name: "Supino", muscle: "Peito")]
        let routines: [WatchRoutine] = []
        let planner = ["ter": ["exercise:ex1:4"]]

        let items = WatchPlannerHelper.resolveTodayPlannedItems(
            routines: routines,
            library: library,
            planner: planner,
            date: makeTuesday()
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .singleExercise)
        XCTAssertEqual(items.first?.exerciseId, "ex1")
        XCTAssertTrue(items.first?.title.contains("Supino") ?? false)
    }

    func testFilteredLibraryPrioritizesPlannedExercises() {
        let library = [
            makeLibraryExercise(id: "ex1", name: "Agachamento", muscle: "Pernas"),
            makeLibraryExercise(id: "ex2", name: "Remada", muscle: "Costas"),
            makeLibraryExercise(id: "ex3", name: "Rosca", muscle: "Bíceps"),
        ]
        let todayKey = WatchPlannerHelper.todayPlannerKey()
        let planner = [todayKey: ["exercise:ex2:3"]]

        let filtered = WatchPlannerHelper.filteredLibraryForWatch(
            library: library,
            planner: planner,
            limit: 2
        )

        XCTAssertEqual(filtered.first?.id, "ex2")
        XCTAssertEqual(filtered.count, 2)
    }
}
