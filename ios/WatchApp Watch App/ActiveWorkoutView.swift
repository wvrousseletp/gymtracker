import SwiftUI
import Combine
#if canImport(WatchKit)
import WatchKit
#endif
#if os(watchOS)
import CoreMotion
#endif

struct PRCelebrationBanner: View {
    let exerciseNames: [String]
    @StateObject var batterySaver = WatchBatterySaverManager.shared
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.8), radius: 6)
                .scaleEffect(batterySaver.isBatterySaverEnabled ? 1.0 : (glowOpacity > 0.5 ? 1.1 : 1.0))

            Text("NOVO RECORDE!")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.yellow)

            if let first = exerciseNames.first {
                Text(first)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.8))
                    .lineLimit(1)
                if exerciseNames.count > 1 {
                    Text("+\(exerciseNames.count - 1) mais")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .yellow.opacity(batterySaver.isBatterySaverEnabled ? 0.3 : glowOpacity), radius: 12)
        .onAppear {
            if !batterySaver.isBatterySaverEnabled {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.9
                }
            }
        }
    }
}

struct ActiveWorkoutView: View {
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    @StateObject var workoutManager = WorkoutManager.shared
    @StateObject var batterySaver = WatchBatterySaverManager.shared
    private let hapticManager = WatchHapticManager.shared
    
    @State private var syncIndicatorOpacity: Double = 0.0
    @State private var fontSizeScale: Double = 1.0
    @State private var cinemaModeEnabled: Bool = false
    @State private var crownFeedbackScale: CGFloat = 1.0
    @State private var crownFeedbackColor: Color = .white
    
    enum CrownFocusedField: Hashable {
        case weight
        case reps
    }
    
    @FocusState private var crownFocus: CrownFocusedField?
    @FocusState private var isCurrentPageFocused: Bool
    @FocusState private var isControlsPageFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    @State private var showingCancelAlert = false
    @State private var showSummary: Bool = false
    @State private var showingFinishSheet = false
    @State private var showPlateCalculator: Bool = false
    @State private var showNotesSheet: Bool = false
    @State private var isRestTimerMinimized: Bool = false
    @State private var activeWorkoutPage: Int = 1
    @State private var elapsedSeconds: Int = 0
    @State private var selectedSetIndexMap: [String: Int] = [:] // exerciseId -> selectedSetIndex
    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0
    @State private var timerCancellable: Cancellable?
    @State private var isLongWorkout: Bool = false
    @State private var uiRefreshInterval: Double = 1.0
    @State private var pulsingFailureSetIndex: String? = nil
    @State private var isCrownLongPressed = false
    
    // Cardio/Isometria state
    @State private var selectedCardioField: String = "distance"
    @State private var isTimeTimerRunning: Bool = false
    @State private var timeTimerElapsed: Int = 0

    let stopwatchTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func muscleColor(for muscle: String) -> Color {
        let lower = muscle.lowercased()
        if lower.contains("peito") || lower.contains("tríc") {
            return Color.orange
        } else if lower.contains("costa") || lower.contains("dorsal") || lower.contains("bíceps") {
            return Color.blue
        } else if lower.contains("perna") || lower.contains("quadrí") || lower.contains("glút") || lower.contains("panturrilha") {
            return Color.green
        } else if lower.contains("ombro") || lower.contains("deltoide") || lower.contains("trapézio") {
            return Color.purple
        } else if lower.contains("abdômen") || lower.contains("core") {
            return Color.yellow
        } else if lower.contains("cardio") || lower.contains("corrida") {
            return Color.cyan
        }
        return Color.orange
    }

    private func resetTimeTimer() {
        isTimeTimerRunning = false
        timeTimerElapsed = 0
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func getSelectedSetIndex(for exercise: WatchActiveExercise, index: Int) -> Int {
        let key = "\(exercise.name)_\(index)"
        let count = exercise.setsState.count
        guard count > 0 else { return 0 }
        
        if let selected = selectedSetIndexMap[key] {
            return max(0, min(selected, count - 1))
        }
        if let firstUncompleted = exercise.setsState.firstIndex(of: false) {
            return firstUncompleted
        }
        return 0
    }

    private func setSelectedSetIndex(for exercise: WatchActiveExercise, index: Int, setIndex: Int) {
        let key = "\(exercise.name)_\(index)"
        selectedSetIndexMap[key] = setIndex
    }

    private func checkAllSetsCompleted(activeWorkout: WatchActiveWorkoutState, overridingSet: (exIdx: Int, setIdx: Int, isDone: Bool)?) -> Bool {
        for (exIdx, exercise) in activeWorkout.exercises.enumerated() {
            for (setIdx, isDone) in exercise.setsState.enumerated() {
                var state = isDone
                if let override = overridingSet, override.exIdx == exIdx, override.setIdx == setIdx {
                    state = override.isDone
                }
                if !state {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Sub-Views for Page 1 (Current Exercise)

    private func cardioControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let pc = (selectedSetIdx >= 0 && selectedSetIdx < exercise.performedCardios.count) ? exercise.performedCardios[selectedSetIdx] : nil
        let distance = pc?.distanceKm ?? 0.0
        let durationSec = pc?.durationSeconds ?? 0
        let durationMin = durationSec / 60
        let isStationary = exercise.isStationary

        return VStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("DISTÂNCIA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(selectedCardioField == "distance" ? .orange : .gray)
                    
                    Spacer()
                    
                    if !isStationary && workoutManager.distance > 0 {
                        Button(action: {
                            let gpsDist = workoutManager.distance / 1000.0
                            connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: gpsDist, duration: durationSec)
                        }) {
                            Text(String(format: "GPS: %.2f km", workoutManager.distance / 1000.0))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            let newDist = max(0.0, distance - 0.1)
                            connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Diminuir distância")
                        .accessibilityHint("Diminui 0.1 km")
                        
                        Text(String(format: "%.1f km", distance))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(selectedCardioField == "distance" ? crownFeedbackColor : .white)
                            .scaleEffect(selectedCardioField == "distance" ? crownFeedbackScale : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: crownFeedbackScale)
                            .frame(minWidth: 48, alignment: .center)
                        
                        Button(action: {
                            let newDist = distance + 0.1
                            connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Aumentar distância")
                        .accessibilityHint("Aumenta 0.1 km")
                    }
                    .padding(3)
                    .background(selectedCardioField == "distance" ? Color.orange.opacity(0.1) : Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedCardioField == "distance" ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedCardioField = "distance"
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DURAÇÃO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(selectedCardioField == "duration" ? .orange : .gray)
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            let newDur = max(0, durationMin - 1)
                            connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Diminuir duração")
                        .accessibilityHint("Diminui 1 minuto")
                        
                        Text("\(durationMin) min")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(selectedCardioField == "duration" ? crownFeedbackColor : .white)
                            .scaleEffect(selectedCardioField == "duration" ? crownFeedbackScale : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: crownFeedbackScale)
                            .frame(minWidth: 48, alignment: .center)
                        
                        Button(action: {
                            let newDur = durationMin + 1
                            connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Aumentar duração")
                        .accessibilityHint("Aumenta 1 minuto")
                    }
                    .padding(3)
                    .background(selectedCardioField == "duration" ? Color.orange.opacity(0.1) : Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedCardioField == "duration" ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedCardioField = "duration"
            }
        }
    }

    private func getHeartRateZone(bpm: Double) -> (name: String, color: Color, level: Int) {
        if bpm <= 0 { return ("--", .gray, 0) }
        if bpm < 115 { return ("Z1 Recup", .blue, 1) }
        if bpm < 138 { return ("Z2 Queima", .green, 2) }
        if bpm < 156 { return ("Z3 Cardio", .yellow, 3) }
        if bpm < 175 { return ("Z4 Limiar", .orange, 4) }
        return ("Z5 Pico", .red, 5)
    }

    private func strengthControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let isFailure = (selectedSetIdx >= 0 && selectedSetIdx < exercise.failureReport.count) ? exercise.failureReport[selectedSetIdx] : false
        let failureRep = (selectedSetIdx >= 0 && selectedSetIdx < exercise.failureReps.count) ? exercise.failureReps[selectedSetIdx] : nil

        return VStack(spacing: 6) {
            HStack {
                Spacer()
                
                // Weight Info Block (Tappable for Plate Calculator)
                Button(action: {
                    showPlateCalculator = true
                    #if canImport(WatchKit)
                    hapticManager.play(.click)
                    #endif
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f kg", exercise.weight))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(crownFeedbackColor)
                            .scaleEffect(crownFeedbackScale)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: crownFeedbackScale)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 12)
                
                // Reps Info Block
                HStack(spacing: 4) {
                    Image(systemName: "arrow.3.trianglepath")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(exercise.measurementType == "time" ? "\(exercise.reps)s" : "\(exercise.reps) reps")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                
                Spacer()
            }
            
            // Quick Copy Previous Set Button (when on set 2+)
            if selectedSetIdx > 0 && exercise.measurementType != "time" {
                Button(action: {
                    connectivityManager.updateExerciseWeightReps(
                        exerciseIndex: exIndex,
                        weight: exercise.weight,
                        reps: exercise.reps
                    )
                    hapticManager.play(.light)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 8))
                        Text("Repetir Carga/Reps (Série \(selectedSetIdx))")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if exercise.measurementType == "time" {
                HStack(spacing: 6) {
                    Button(action: {
                        isTimeTimerRunning.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isTimeTimerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isTimeTimerRunning ? .orange : .green)
                            
                            let timeToShow = timeTimerElapsed > 0 ? timeTimerElapsed : exercise.reps
                            Text(String(format: "%02d:%02d", timeToShow / 60, timeToShow % 60))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if timeTimerElapsed > 0 {
                        Button(action: {
                            resetTimeTimer()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 22)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            // Record time
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: timeTimerElapsed)
                            #if canImport(WatchKit)
                            hapticManager.playSetCompleted()
                            #endif
                            resetTimeTimer()
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                                .frame(width: 24, height: 22)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 2)
            }
            
            // Compact Failure Toggle
            Button(action: {
                #if canImport(WatchKit)
                if !isFailure {
                    hapticManager.playFailureRegistered()
                } else {
                    hapticManager.playFailureRemoved()
                }
                #endif
                connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: !isFailure, failureRep: nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isFailure ? "xmark.octagon.fill" : "xmark.octagon")
                        .font(.system(size: 9))
                    Text(isFailure ? "FALHA REGISTRADA" : "REGISTRAR FALHA")
                        .font(.system(size: 9, weight: .black))
                }
                .foregroundColor(isFailure ? .red : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isFailure ? Color.red.opacity(0.12) : Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFailure ? Color.red.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isFailure ? "Falha registrada" : "Registrar falha")
            .accessibilityHint(isFailure ? "Toque para remover falha" : "Toque para registrar falha nesta série")
            
            if isFailure {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REPETIÇÃO DA FALHA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                    
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                let current = failureRep ?? exercise.reps
                                let newR = max(1, current - 1)
                                connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(width: 32, height: 32)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("\(failureRep ?? exercise.reps)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(minWidth: 48, alignment: .center)
                            
                            Button(action: {
                                let current = failureRep ?? exercise.reps
                                let newR = current + 1
                                connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(width: 32, height: 32)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(3)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Battery Indicator View
    
    private func batteryIndicatorView() -> some View {
        HStack(spacing: 4) {
            Image(systemName: batterySaver.batteryState == .charging ? "battery.charging.fill" : "battery.fill")
                .font(.system(size: 8))
                .foregroundColor(batteryColor())
            
            Text("\(batterySaver.batteryPercentage)%")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(batteryColor())
            
            if batterySaver.isBatterySaverEnabled {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.yellow)
            }
            
            // Sync indicator
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 7))
                .foregroundColor(.blue)
                .opacity(syncIndicatorOpacity)
                .rotationEffect(.degrees(syncIndicatorOpacity > 0 ? 360 : 0))
                .animation(syncIndicatorOpacity > 0 ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncIndicatorOpacity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(batterySaver.isCriticalBattery ? Color.red.opacity(0.2) : Color.white.opacity(0.05))
        .cornerRadius(6)
        .accessibilityLabel(accessibilityLabelForBattery())
        .accessibilityHint(batterySaver.isBatterySaverEnabled ? "Modo economia de bateria ativado" : "")
    }
    
    private func accessibilityLabelForBattery() -> String {
        var label = "Bateria: \(batterySaver.batteryPercentage)%"
        if batterySaver.batteryState == .charging {
            label += ", carregando"
        }
        if batterySaver.isCriticalBattery {
            label += ", bateria crítica"
        } else if batterySaver.isLowBattery {
            label += ", bateria baixa"
        }
        return label
    }
    
    private func batteryColor() -> Color {
        if batterySaver.isCriticalBattery {
            return .red
        } else if batterySaver.isLowBattery {
            return .orange
        } else if batterySaver.isBatterySaverEnabled {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func showSyncIndicator() {
        withAnimation {
            syncIndicatorOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                syncIndicatorOpacity = 0.0
            }
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private func accessibilityLabelForSet(setIndex: Int, isCompleted: Bool, isFailure: Bool, isSelected: Bool) -> String {
        var label = "Série \(setIndex + 1)"
        if isCompleted {
            label += ", concluída"
        }
        if isFailure {
            label += ", falha registrada"
        }
        if isSelected {
            label += ", selecionada"
        }
        return label
    }
    
    // MARK: - Workout Progress Indicator
    
    private func workoutProgressView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let totalExercises = activeWorkout.exercises.count
        let currentExerciseIndex = activeWorkout.currentExerciseIndex + 1
        let totalSets = activeWorkout.exercises.reduce(0) { $0 + $1.sets }
        let completedSets = activeWorkout.exercises.reduce(0) { $0 + $1.setsState.filter { $0 }.count }
        let progress = totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0.0
        
        return VStack(spacing: 2) {
            HStack(spacing: 8) {
                // Exercise progress
                HStack(spacing: 2) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                    Text("\(currentExerciseIndex)/\(totalExercises)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Sets progress
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                    Text("\(completedSets)/\(totalSets)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.orange, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * progress, height: 3)
                }
                .cornerRadius(1.5)
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 4)
        .accessibilityLabel("Progresso do treino: exercício \(currentExerciseIndex) de \(totalExercises), \(completedSets) de \(totalSets) séries concluídas")
        .accessibilityValue("\(Int(progress * 100))%")
    }

    private func currentExercisePageView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let exIndex = activeWorkout.currentExerciseIndex
        
        return VStack(spacing: 0) {
            // Minimized Rest Timer Bar (if running and minimized)
            if let restTimer = activeWorkout.restTimer, isRestTimerMinimized {
                Button(action: {
                    withAnimation(.spring()) {
                        isRestTimerMinimized = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                        Text(restTimer.isPrep ? "PREPARO" : "DESCANSO ATIVO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.35), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            
            // Battery Indicator
            if !isLuminanceReduced {
                batteryIndicatorView()
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
            
            // Workout Progress
            workoutProgressView(activeWorkout: activeWorkout)
                .padding(.bottom, 2)
            
            if exIndex >= 0 && exIndex < activeWorkout.exercises.count {
                let exercise = activeWorkout.exercises[exIndex]
                let isCardio = exercise.isCardio
                let themeAccent = muscleColor(for: exercise.muscle)
                
                VStack(spacing: 4) {
                    // 1. Exercise Info Header with Navigation Chevrons & Notes button
                    HStack(alignment: .center) {
                        Button(action: {
                            connectivityManager.changeExercise(to: exIndex - 1)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeAccent)
                        }
                        .disabled(exIndex == 0 || isLuminanceReduced)
                        .opacity(isLuminanceReduced ? 0.0 : (exIndex == 0 ? 0.2 : 1.0))
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 24, height: 24)
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 0) {
                            HStack(spacing: 3) {
                                Text(exercise.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(themeAccent)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    showNotesSheet = true
                                    #if canImport(WatchKit)
                                    hapticManager.play(.click)
                                    #endif
                                }) {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 8))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            HStack(spacing: 4) {
                                Text(exercise.muscle)
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                if let exec = exercise.executionType, !exec.isEmpty {
                                    Text("•")
                                        .font(.system(size: 7))
                                        .foregroundColor(.gray)
                                    Text(exec)
                                        .font(.system(size: 7))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            connectivityManager.changeExercise(to: exIndex + 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeAccent)
                        }
                        .disabled(exIndex + 1 >= activeWorkout.exercises.count || isLuminanceReduced)
                        .opacity(isLuminanceReduced ? 0.0 : (exIndex + 1 >= activeWorkout.exercises.count ? 0.2 : 1.0))
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 24, height: 24)
                    }
                    .padding(.horizontal, 2)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                if value.translation.width > threshold && exIndex > 0 {
                                    // Swipe right - previous exercise
                                    connectivityManager.changeExercise(to: exIndex - 1)
                                } else if value.translation.width < -threshold && exIndex + 1 < activeWorkout.exercises.count {
                                    // Swipe left - next exercise
                                    connectivityManager.changeExercise(to: exIndex + 1)
                                }
                            }
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // 2. Compact Horizontal Sets Row (Tappable circles/capsules)
                    let activeSetIdx = getSelectedSetIndex(for: exercise, index: exIndex)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<exercise.sets, id: \.self) { setIndex in
                            let isCompleted = setIndex < exercise.setsState.count ? exercise.setsState[setIndex] : false
                            let isSelected = setIndex == activeSetIdx
                            let isFailure = setIndex < exercise.failureReport.count ? exercise.failureReport[setIndex] : false
                            let checkmarkColor = isCardio ? Color.blue : Color.green
                            
                            Button(action: {
                                // Tap selects the set. If already selected, taps toggle/complete it!
                                if isSelected {
                                    let failureRep = (activeSetIdx >= 0 && activeSetIdx < exercise.failureReps.count) ? exercise.failureReps[activeSetIdx] : nil
                                    let pc = (activeSetIdx >= 0 && activeSetIdx < exercise.performedCardios.count) ? exercise.performedCardios[activeSetIdx] : nil
                                    
                                    #if canImport(WatchKit)
                                    if !isCompleted {
                                        if isFailure {
                                            hapticManager.playFailureRegistered()
                                        } else {
                                            hapticManager.playSetCompleted()
                                        }
                                    } else {
                                        hapticManager.playSetUncompleted()
                                    }
                                    #endif

                                    connectivityManager.toggleSet(
                                        exerciseIndex: exIndex,
                                        setIndex: setIndex,
                                        isDone: !isCompleted,
                                        isFailure: isFailure,
                                        failureRep: failureRep,
                                        distance: pc?.distanceKm,
                                        duration: pc?.durationSeconds
                                    )
                                    
                                    showSyncIndicator()
                                    
                                    // Trigger pulse effect when failure is registered
                                    if !isCompleted && isFailure {
                                        let key = "\(exercise.name)_\(exIndex)_\(setIndex)"
                                        pulsingFailureSetIndex = key
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            pulsingFailureSetIndex = nil
                                        }
                                    }
                                    
                                    if !isCompleted {
                                        let willCompleteWorkout = checkAllSetsCompleted(activeWorkout: activeWorkout, overridingSet: (exIdx: exIndex, setIdx: setIndex, isDone: true))
                                        if willCompleteWorkout {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                showSummary = true
                                            }
                                        }
                                    }
                                } else {
                                    setSelectedSetIndex(for: exercise, index: exIndex, setIndex: setIndex)
                                }
                            }) {
                                let key = "\(exercise.name)_\(exIndex)_\(setIndex)"
                                let isPulsing = pulsingFailureSetIndex == key
                                setButtonView(
                                    setIndex: setIndex,
                                    isSelected: isSelected,
                                    isCompleted: isCompleted,
                                    isFailure: isFailure,
                                    isCardio: isCardio,
                                    isPulsing: isPulsing,
                                    checkmarkColor: checkmarkColor
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 2)
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // 3. Ultra Compact Info & Quick Toggle Controls Area (Weights & Reps + Compact Toggle)
                    VStack(spacing: 4) {
                        if isCardio {
                            cardioControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: activeSetIdx)
                        } else {
                            strengthControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: activeSetIdx)
                        }
                        
                        if !isLuminanceReduced {
                            // Solid Concluir/Desfazer button shrunk down
                            Button(action: {
                                let isCompleted = (activeSetIdx >= 0 && activeSetIdx < exercise.setsState.count) ? exercise.setsState[activeSetIdx] : false
                                let isFailure = (activeSetIdx >= 0 && activeSetIdx < exercise.failureReport.count) ? exercise.failureReport[activeSetIdx] : false
                                let failureRep = (activeSetIdx >= 0 && activeSetIdx < exercise.failureReps.count) ? exercise.failureReps[activeSetIdx] : nil
                                let pc = (activeSetIdx >= 0 && activeSetIdx < exercise.performedCardios.count) ? exercise.performedCardios[activeSetIdx] : nil
                                
                                #if canImport(WatchKit)
                                if !isCompleted {
                                    if isFailure {
                                        hapticManager.playFailureRegistered()
                                    } else {
                                        hapticManager.playSetCompleted()
                                    }
                                } else {
                                    hapticManager.playSetUncompleted()
                                }
                                #endif

                                connectivityManager.toggleSet(
                                            exerciseIndex: exIndex,
                                            setIndex: activeSetIdx,
                                            isDone: !isCompleted,
                                            isFailure: isFailure,
                                            failureRep: failureRep,
                                            distance: pc?.distanceKm,
                                            duration: pc?.durationSeconds
                                        )
                                        
                                if !isCompleted {
                                    let willCompleteWorkout = checkAllSetsCompleted(activeWorkout: activeWorkout, overridingSet: (exIdx: exIndex, setIdx: activeSetIdx, isDone: true))
                                    if willCompleteWorkout {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            showSummary = true
                                        }
                                    }
                                }
                            }) {
                                let isCompleted = (activeSetIdx >= 0 && activeSetIdx < exercise.setsState.count) ? exercise.setsState[activeSetIdx] : false
                                HStack(spacing: 4) {
                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(isCompleted ? .white : .black)
                                    Text(isCompleted ? "CONCLUÍDO" : "CONCLUIR SÉRIE")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(isCompleted ? .white : .black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(isCompleted ? Color.gray.opacity(0.3) : Color.green)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 4)
            } else {
                Text("Nenhum exercício ativo")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .focusable()
        .focused($isCurrentPageFocused)
        .onAppear {
            isCurrentPageFocused = true
        }
    }

    private func workoutControlsPageView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let hrZone = getHeartRateZone(bpm: workoutManager.heartRate)
        
        return VStack(spacing: 4) {
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("TEMPO TOTAL")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text(formatDuration(elapsedSeconds))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(activeWorkout.paused ? .orange : .green)
                }
                
                Spacer()
                
                // HealthKit Metrics
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 8))
                            Text("BPM")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        HStack(spacing: 3) {
                            Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if workoutManager.heartRate > 0 {
                                Text(hrZone.name)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(hrZone.color)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(hrZone.color.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 8))
                            Text("CALORIAS")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        Text(workoutManager.activeCalories > 0 ? "\(Int(workoutManager.activeCalories))" : "--")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 4) {
                // Pause/Resume Workout
                Button(action: {
                    connectivityManager.togglePause(currentlyPaused: activeWorkout.paused)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: activeWorkout.paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(activeWorkout.paused ? "Retomar" : "Pausar")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(activeWorkout.paused ? .green : .orange)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(activeWorkout.paused ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(activeWorkout.paused ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Adiar Treino (Postpone)
                Button(action: {
                    connectivityManager.postponeWorkout()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "snooze")
                            .font(.system(size: 8, weight: .bold))
                        Text("Adiar Treino")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    showSummary = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Finalizar")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.green)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Cancelar Treino
                Button(action: {
                    showingCancelAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Cancelar")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)
        }
        .focusable()
        .focused($isControlsPageFocused)
        .onAppear {
            isControlsPageFocused = true
        }
    }

    @ViewBuilder
    private func activeWorkoutMainView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let exIndex = activeWorkout.currentExerciseIndex
        let currentMuscle = (exIndex >= 0 && exIndex < activeWorkout.exercises.count) ? activeWorkout.exercises[exIndex].muscle : ""
        let glowColor = muscleColor(for: currentMuscle)

        ZStack {
            if !isLuminanceReduced {
                RadialGradient(
                    colors: [glowColor.opacity(0.12), Color.black],
                    center: .top,
                    startRadius: 10,
                    endRadius: 180
                )
                .ignoresSafeArea()
            }

            TabView(selection: $activeWorkoutPage) {
                // Page 0: Controles do Treino (Padrão Apple Workout: controles à esquerda)
                if !isLuminanceReduced {
                    workoutControlsPageView(activeWorkout: activeWorkout)
                        .tag(0)
                }
                
                // Page 1: Exercício Ativo & Séries (Principal no centro)
                currentExercisePageView(activeWorkout: activeWorkout)
                    .tag(1)
                
                // Page 2: Controles de Música (NowPlaying à direita)
                #if os(watchOS)
                if !isLuminanceReduced {
                    NowPlayingView()
                        .tag(2)
                }
                #endif
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .focusable()
            .digitalCrownRotation($crownValue, from: 0, through: 100, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { newValue in
                if isControlsPageFocused {
                    adjustFontSize(delta: newValue - lastCrownValue)
                } else {
                    handleCrownRotation(newValue: newValue, oldValue: lastCrownValue, activeWorkout: activeWorkout)
                }
                lastCrownValue = newValue
            }
        }
    }
    
    private func handleCrownRotation(newValue: Double, oldValue: Double, activeWorkout: WatchActiveWorkoutState) {
        let delta = Int(newValue - oldValue)
        guard delta != 0 else { return }
        
        guard activeWorkout.currentExerciseIndex >= 0 && activeWorkout.currentExerciseIndex < activeWorkout.exercises.count else { return }
        let exercise = activeWorkout.exercises[activeWorkout.currentExerciseIndex]
        let isCardio = exercise.isCardio
        
        if isCardio {
            let activeSetIdx = getSelectedSetIndex(for: exercise, index: activeWorkout.currentExerciseIndex)
            let pc = activeSetIdx >= 0 && activeSetIdx < exercise.performedCardios.count ? exercise.performedCardios[activeSetIdx] : nil
            let currentDistance = pc?.distanceKm ?? 0.0
            let currentDuration = pc?.durationSeconds ?? 0
            
            if selectedCardioField == "distance" {
                let newDistance = max(0.0, currentDistance + Double(delta) * 0.1)
                connectivityManager.updateCardio(exerciseIndex: activeWorkout.currentExerciseIndex, setIndex: activeSetIdx, distance: newDistance, duration: currentDuration)
            } else {
                let newDuration = max(0, currentDuration + delta * 30) // Scroll shifts by 30s
                connectivityManager.updateCardio(exerciseIndex: activeWorkout.currentExerciseIndex, setIndex: activeSetIdx, distance: currentDistance, duration: newDuration)
            }
        } else {
            // Adjust weight
            let currentWeight = exercise.weight
            let newWeight = max(0, currentWeight + Double(delta) * 0.5)
            connectivityManager.updateExerciseWeightReps(exerciseIndex: activeWorkout.currentExerciseIndex, weight: newWeight, reps: exercise.reps)
        }
        
        #if canImport(WatchKit)
        hapticManager.playCrownRotation()
        #endif
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            crownFeedbackScale = 1.15
            crownFeedbackColor = .green
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.2)) {
                crownFeedbackScale = 1.0
                crownFeedbackColor = .white
            }
        }
    }
    
    private func handleCrownLongPress(activeWorkout: WatchActiveWorkoutState) {
        // Long press on crown toggles pause/resume
        connectivityManager.togglePause(currentlyPaused: activeWorkout.paused)
        
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
    
    // MARK: - Font Size Adjustment
    
    private func adjustFontSize(delta: Double) {
        let newScale = max(0.8, min(1.3, fontSizeScale + delta * 0.05))
        fontSizeScale = newScale
        
        // Save to UserDefaults
        UserDefaults.standard.set(fontSizeScale, forKey: "font_size_scale")
    }
    
    private func loadFontSizeScale() {
        let savedScale = UserDefaults.standard.double(forKey: "font_size_scale")
        if savedScale > 0 {
            fontSizeScale = savedScale
        }
    }
    
    // MARK: - Cinema Mode (Accelerometer-based)
    
    #if os(watchOS)
    private let motionManager = CMMotionManager()
    @State private var motionUpdateTimer: Timer?
    #endif
    
    @ViewBuilder
    private func setButtonView(
        setIndex: Int,
        isSelected: Bool,
        isCompleted: Bool,
        isFailure: Bool,
        isCardio: Bool,
        isPulsing: Bool,
        checkmarkColor: Color
    ) -> some View {
        let bgColor: Color = isSelected 
            ? (isCompleted ? .green : .orange) 
            : (isCompleted ? .green.opacity(0.15) : .white.opacity(0.04))
        let strokeColor: Color = isFailure && isPulsing 
            ? .red.opacity(0.8) 
            : (isSelected ? .white.opacity(0.8) : .white.opacity(0.06))
        
        VStack(spacing: 2) {
            Text("\(setIndex + 1)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .black : .white)
            
            if isFailure && !isCardio {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            } else if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold)) // increased from 8
                    .foregroundColor(isSelected ? .black : checkmarkColor)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 10)) // increased from 8
                    .foregroundColor(isSelected ? .black.opacity(0.4) : .white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8) // increased from 4
        .background(bgColor)
        .cornerRadius(8) // increased from 6
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: isFailure && isPulsing ? 2 : 1)
        )
        .contentShape(Rectangle()) // Makes the whole area tappable
        .accessibilityLabel(accessibilityLabelForSet(setIndex: setIndex, isCompleted: isCompleted, isFailure: isFailure, isSelected: isSelected))
    }

    private func startCinemaModeMonitoring() {
        #if os(watchOS)
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.5
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let acceleration = data?.acceleration else { return }
            
            // Detect if wrist is down (negative z acceleration)
            let isWristDown = acceleration.z < -0.5
            
            // Enable cinema mode when wrist is down and battery saver is active
            if isWristDown && batterySaver.isBatterySaverEnabled {
                if !cinemaModeEnabled {
                    cinemaModeEnabled = true
                }
            } else {
                if cinemaModeEnabled {
                    cinemaModeEnabled = false
                }
            }
        }
        #endif
    }
    
    private func stopCinemaModeMonitoring() {
        #if os(watchOS)
        motionManager.stopAccelerometerUpdates()
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil
        
        // Restore normal brightness
        if cinemaModeEnabled {
            cinemaModeEnabled = false
        }
        #endif
    }
    

    var body: some View {
        Group {
            if showSummary, let activeWorkout = connectivityManager.activeWorkout {
                WorkoutSummaryView(activeWorkout: activeWorkout)
            } else if let activeWorkout = connectivityManager.activeWorkout {
                if let restTimer = activeWorkout.restTimer, !isRestTimerMinimized {
                    RestTimerView(restTimer: restTimer, onMinimize: {
                        withAnimation(.spring()) {
                            isRestTimerMinimized = true
                        }
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    activeWorkoutMainView(activeWorkout: activeWorkout)
                        .onAppear {
                            timerCancellable = stopwatchTimer.sink { _ in
                                elapsedSeconds += 1
                            }
                            loadFontSizeScale()
                            startCinemaModeMonitoring()
                        }
                        .onDisappear {
                            timerCancellable?.cancel()
                            stopCinemaModeMonitoring()
                        }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Nenhum treino ativo")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Inicie um treino no iPhone\nou nesta tela.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationBarHidden(true) // Remove "Treino" text from the top of watch screens
        .alert(isPresented: $showingCancelAlert) {
            Alert(
                title: Text("Cancelar Treino?"),
                message: Text("Isso apagará o progresso do treino atual."),
                primaryButton: .destructive(Text("Sim")) {
                    connectivityManager.cancelWorkout()
                },
                secondaryButton: .cancel(Text("Não"))
            )
        }
        .sheet(isPresented: $showingFinishSheet) {
            FinishWorkoutSheet(isPresented: $showingFinishSheet) { rpe, notes in
                connectivityManager.completeWorkout(rpe: rpe, notes: notes)
            }
        }
        .sheet(isPresented: $showPlateCalculator) {
            if let activeWorkout = connectivityManager.activeWorkout,
               activeWorkout.currentExerciseIndex >= 0 && activeWorkout.currentExerciseIndex < activeWorkout.exercises.count {
                let currentWeight = activeWorkout.exercises[activeWorkout.currentExerciseIndex].weight
                WatchPlateCalculatorView(targetWeight: currentWeight)
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            if let activeWorkout = connectivityManager.activeWorkout,
               activeWorkout.currentExerciseIndex >= 0 && activeWorkout.currentExerciseIndex < activeWorkout.exercises.count {
                let exercise = activeWorkout.exercises[activeWorkout.currentExerciseIndex]
                WatchExerciseNotesView(
                    exerciseName: exercise.name,
                    existingNote: "",
                    onSave: { note in
                        // Future: Sync exercise specific notes
                    }
                )
            }
        }
        .onChange(of: connectivityManager.activeWorkout?.restTimer == nil) { isFinished in
            if isFinished {
                isRestTimerMinimized = false
            }
        }
        .overlay(
            Group {
                if !connectivityManager.prExerciseNames.isEmpty {
                    VStack {
                        PRCelebrationBanner(exerciseNames: connectivityManager.prExerciseNames)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        Spacer()
                    }
                    .padding(.top, 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: connectivityManager.prExerciseNames)
                }
            }
        )
        .onAppear {
            connectivityManager.requestSync()
            updateStopwatch()
            crownFocus = .reps
            isCurrentPageFocused = true
            isControlsPageFocused = true
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                isCurrentPageFocused = true
                isControlsPageFocused = true
            }
        }
        .onChange(of: connectivityManager.activeWorkout?.currentExerciseIndex) { _ in
            resetTimeTimer()
        }
        .onReceive(stopwatchTimer) { _ in
            if !isLuminanceReduced {
                updateStopwatch()
            }
            if isTimeTimerRunning {
                timeTimerElapsed += 1
                if let activeWorkout = connectivityManager.activeWorkout {
                    let exIdx = activeWorkout.currentExerciseIndex
                    if exIdx >= 0 && exIdx < activeWorkout.exercises.count {
                        let exercise = activeWorkout.exercises[exIdx]
                        if timeTimerElapsed == exercise.reps {
                            hapticManager.playIsometryFinished()
                        }
                    }
                }
            }
        }
        .onChange(of: isLuminanceReduced) { reduced in
            if !reduced {
                updateStopwatch()
            }
        }
        .onChange(of: connectivityManager.prExerciseNames) { names in
            if !names.isEmpty {
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.retry)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    WKInterfaceDevice.current().play(.success)
                }
                #endif
            }
        }
    }

    private func updateStopwatch() {
        if let activeWorkout = connectivityManager.activeWorkout, !activeWorkout.paused {
            let currentTimeMs = Int64(Date().timeIntervalSince1970 * 1000)
            let diff = currentTimeMs - activeWorkout.startTime
            let seconds = Int(clamping: diff / 1000)
            
            // Auto-adjust refresh interval for long workouts to save battery
            if seconds > 1800 && !isLongWorkout {
                isLongWorkout = true
                uiRefreshInterval = 5.0 // Update UI every 5 seconds for long workouts
            } else if seconds <= 1800 && isLongWorkout {
                isLongWorkout = false
                uiRefreshInterval = 1.0 // Restore normal refresh rate
            }
            
            // Only update UI if enough time has passed based on refresh interval
            let shouldUpdateUI = seconds % max(1, Int(uiRefreshInterval)) == 0
            
            if shouldUpdateUI {
                elapsedSeconds = max(0, seconds)
            }
        } else if let activeWorkout = connectivityManager.activeWorkout {
            elapsedSeconds = activeWorkout.elapsedSeconds
        }
    }
}
import SwiftUI

struct WorkoutSummaryView: View {
    let activeWorkout: WatchActiveWorkoutState
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    
    // Calcula o peso total (tonelagem)
    private var totalVolume: Double {
        var vol: Double = 0
        for exercise in activeWorkout.exercises {
            if !exercise.isCardio {
                let completedSets = exercise.setsState.filter { $0 }.count
                vol += exercise.weight * Double(exercise.reps) * Double(completedSets)
            }
        }
        return vol
    }
    
    // Calcula as calorias estimadas (bem básico)
    private var estimatedCalories: Int {
        let durationMinutes = Double(activeWorkout.elapsedSeconds) / 60.0
        return Int(durationMinutes * 6.5) // ~6.5 kcal por minuto
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m) min"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                        .padding(.top, 12)
                    
                    Text("TREINO CONCLUÍDO!")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(activeWorkout.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 8)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatCard(title: "Tempo", value: formatDuration(activeWorkout.elapsedSeconds), icon: "timer", color: .blue)
                    StatCard(title: "Calorias", value: "\(estimatedCalories) kcal", icon: "flame.fill", color: .orange)
                    StatCard(title: "Volume", value: String(format: "%.0f kg", totalVolume), icon: "scalemass.fill", color: .purple)
                    
                    let completedExercises = activeWorkout.exercises.filter { ex in !ex.setsState.contains(false) }.count
                    StatCard(title: "Exercícios", value: "\(completedExercises)/\(activeWorkout.exercises.count)", icon: "figure.strengthtraining.traditional", color: .green)
                }
                
                // Botão Finalizar
                Button(action: {
                    #if canImport(WatchKit)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                    connectivityManager.completeWorkout(rpe: 8, notes: "Concluído no Watch")
                }) {
                    Text("Finalizar Treino")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.green)
                        .cornerRadius(22)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            #if canImport(WatchKit)
            WatchHapticManager.shared.playWorkoutFinish()
            #endif
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}
