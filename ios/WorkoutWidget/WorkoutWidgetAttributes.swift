import ActivityKit
import Foundation

struct WorkoutWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSetInfo: String
        var isPaused: Bool
        var elapsedSeconds: Int
        // Rest timer fields (nil = no active rest)
        var restTimerEndDate: Date?
        var restTimerTotalSeconds: Int
        var restIsPrep: Bool
        // Series progress
        var completedSets: Int
        var totalSets: Int
        var isCardio: Bool
    }
    
    var workoutName: String
}
