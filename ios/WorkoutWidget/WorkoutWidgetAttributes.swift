import ActivityKit
import Foundation

struct WorkoutWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSetInfo: String
        var isPaused: Bool
        var elapsedSeconds: Int
    }
    
    var workoutName: String
}
