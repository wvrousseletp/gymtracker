import WidgetKit
import SwiftUI

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayRoutineWidget()
        WaterIntakeWidget()
        if #available(iOS 16.1, *) {
            WorkoutLiveActivity()
        }
    }
}
