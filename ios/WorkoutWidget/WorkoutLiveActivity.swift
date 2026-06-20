import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutWidgetAttributes.self) { context in
            // Lock Screen/Notification View
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.workoutName.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.orange)
                        Text(context.state.exerciseName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    Text(context.state.currentSetInfo)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    if context.state.isPaused {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("Pausado")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text(Date(timeIntervalSinceNow: Double(-context.state.elapsedSeconds)), style: .timer)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.9))
            .activityBackgroundTint(Color.black)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded layout
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("Los Mooscles")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.orange)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if context.state.isPaused {
                            Text("Pausado")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                        } else {
                            Text(Date(timeIntervalSinceNow: Double(-context.state.elapsedSeconds)), style: .timer)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(context.state.currentSetInfo)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.orange)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("Paused")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                } else {
                    Text(Date(timeIntervalSinceNow: Double(-context.state.elapsedSeconds)), style: .timer)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .frame(width: 40)
                }
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.orange)
            }
        }
    }
}
