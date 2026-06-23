import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Gauge-style ring for rest timer progress
@available(iOSApplicationExtension 16.1, *)
struct RestRing: View {
    let totalSeconds: Int
    let endDate: Date
    let isPrep: Bool
    let size: CGFloat
    
    private var accentColor: Color { isPrep ? .yellow : .orange }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: size * 0.12)
            ProgressView(timerInterval: Date()...endDate, countsDown: true)
                .progressViewStyle(.circular)
                .tint(accentColor)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

@available(iOSApplicationExtension 16.1, *)
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutWidgetAttributes.self) { context in
            // ────────────────────────────────────────────
            // LOCK SCREEN / NOTIFICATION BANNER VIEW
            // ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    // App icon area
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.attributes.workoutName.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.orange)
                            .kerning(0.6)
                        Text(context.state.exerciseName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Workout stopwatch (always visible)
                    if context.state.isPaused {
                        Label("Pausado", systemImage: "pause.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        Text(Date(timeIntervalSinceNow: Double(-context.state.elapsedSeconds)), style: .timer)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                }
                
                Divider().overlay(Color.white.opacity(0.1))
                
                // Rest timer section (shows when rest is active)
                if let endDate = context.state.restTimerEndDate,
                   endDate > Date() {
                    let isPrep = context.state.restIsPrep
                    let accent: Color = isPrep ? .yellow : .orange
                    
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(accent.opacity(0.18), lineWidth: 3)
                                .frame(width: 36, height: 36)
                            ProgressView(timerInterval: Date()...endDate, countsDown: true)
                                .progressViewStyle(.circular)
                                .tint(accent)
                                .frame(width: 28, height: 28)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isPrep ? "TEMPO DE PREPARO" : "DESCANSO ATIVO")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(accent)
                                .kerning(0.5)
                            HStack(spacing: 4) {
                                Text(endDate, style: .timer)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                Text("restantes")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        // Next exercise info
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("PRÓXIMO")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white.opacity(0.4))
                            Text(context.state.currentSetInfo)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    // No rest: show set info
                    Text(context.state.currentSetInfo)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.92))
            .activityBackgroundTint(Color.black)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // ─── EXPANDED ───
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.orange)
                            .font(.system(size: 11, weight: .bold))
                        Text("Los Mooscles")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.orange)
                            .kerning(0.3)
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
                                .monospacedDigit()
                        }
                    }
                    .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if let endDate = context.state.restTimerEndDate,
                       endDate > Date() {
                        let isPrep = context.state.restIsPrep
                        let accent: Color = isPrep ? .yellow : .orange
                        
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .stroke(accent.opacity(0.2), lineWidth: 3)
                                    .frame(width: 40, height: 40)
                                ProgressView(timerInterval: Date()...endDate, countsDown: true)
                                    .progressViewStyle(.circular)
                                    .tint(accent)
                                    .frame(width: 30, height: 30)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(isPrep ? "PREPARO" : "DESCANSO")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(accent)
                                Text(endDate, style: .timer)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(context.state.exerciseName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(context.state.currentSetInfo)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(context.state.currentSetInfo)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 4)
                        .padding(.bottom, 4)
                    }
                }
                
            } compactLeading: {
                // Compact: show rest timer icon when resting, else workout icon
                if let endDate = context.state.restTimerEndDate, endDate > Date() {
                    let isPrep = context.state.restIsPrep
                    Image(systemName: isPrep ? "bolt.fill" : "timer")
                        .foregroundColor(isPrep ? .yellow : .orange)
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                }
                
            } compactTrailing: {
                // Compact trailing: rest countdown takes priority over workout time
                if let endDate = context.state.restTimerEndDate, endDate > Date() {
                    let isPrep = context.state.restIsPrep
                    Text(endDate, style: .timer)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(isPrep ? .yellow : .orange)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                } else if context.state.isPaused {
                    Text("Paused")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                } else {
                    Text(Date(timeIntervalSinceNow: Double(-context.state.elapsedSeconds)), style: .timer)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .frame(width: 40)
                        .monospacedDigit()
                }
                
            } minimal: {
                if let endDate = context.state.restTimerEndDate, endDate > Date() {
                    let isPrep = context.state.restIsPrep
                    Image(systemName: isPrep ? "bolt.fill" : "timer")
                        .foregroundColor(isPrep ? .yellow : .orange)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.orange)
                }
            }
        }
    }
}
