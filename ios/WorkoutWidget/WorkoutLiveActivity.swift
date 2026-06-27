import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

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
            LockScreenWidgetView(context: context)
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
                    DynamicIslandExpandedBottomView(context: context)
                }
                
            } compactLeading: {
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
                    // Show compact progress: checkmark and e.g., 2/3
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text("\(context.state.completedSets)/\(context.state.totalSets)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
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

// MARK: - Lock Screen Widget View
@available(iOSApplicationExtension 16.1, *)
struct LockScreenWidgetView: View {
    let context: ActivityViewContext<WorkoutWidgetAttributes>
    
    var body: some View {
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
                    
                    #if compiler(>=5.9)
                    if #available(iOS 17.0, *) {
                        Button(intent: SkipRestIntent()) {
                            HStack(spacing: 3) {
                                Image(systemName: "forward.fill")
                                Text("Pular")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accent.opacity(0.35))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Link(destination: URL(string: "losmooscles://skipRest")!) {
                            HStack(spacing: 3) {
                                Image(systemName: "forward.fill")
                                Text("Pular")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accent.opacity(0.35))
                            .cornerRadius(12)
                        }
                    }
                    #else
                    Link(destination: URL(string: "losmooscles://skipRest")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "forward.fill")
                            Text("Pular")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.35))
                        .cornerRadius(12)
                    }
                    #endif
                    
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
                // No rest: show set info and interactive buttons
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.currentSetInfo)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        // Series dots
                        HStack(spacing: 3) {
                            ForEach(0..<context.state.totalSets, id: \.self) { index in
                                Circle()
                                    .fill(index < context.state.completedSets ? Color.green : Color.gray.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    #if compiler(>=5.9)
                    if #available(iOS 17.0, *) {
                        HStack(spacing: 8) {
                            Button(intent: TogglePauseIntent()) {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: CompleteSetIntent()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Concluir")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    #endif
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.92))
    }
}

// MARK: - Dynamic Island Expanded Bottom View
@available(iOSApplicationExtension 16.1, *)
struct DynamicIslandExpandedBottomView: View {
    let context: ActivityViewContext<WorkoutWidgetAttributes>
    
    var body: some View {
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
                
                #if compiler(>=5.9)
                if #available(iOS 17.0, *) {
                    Button(intent: SkipRestIntent()) {
                        Text("Pular")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.35))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "losmooscles://skipRest")!) {
                        Text("Pular")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.35))
                            .cornerRadius(8)
                    }
                }
                #else
                Link(destination: URL(string: "losmooscles://skipRest")!) {
                    Text("Pular")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.35))
                        .cornerRadius(8)
                }
                #endif
                
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(context.state.currentSetInfo)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    // Progress Dots
                    HStack(spacing: 3) {
                        ForEach(0..<context.state.totalSets, id: \.self) { index in
                            Circle()
                                .fill(index < context.state.completedSets ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                #if compiler(>=5.9)
                if #available(iOS 17.0, *) {
                    HStack(spacing: 8) {
                        Button(intent: TogglePauseIntent()) {
                            HStack {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                Text(context.state.isPaused ? "Retomar" : "Pausar")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: CompleteSetIntent()) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Concluir Série")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(intent: FinishWorkoutIntent()) {
                            Text("Finalizar")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                #endif
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
}
