import SwiftUI
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

struct PRCelebrationBanner: View {
    let exerciseNames: [String]
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.8), radius: 6)
                .scaleEffect(glowOpacity > 0.5 ? 1.1 : 1.0)

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
        .shadow(color: .yellow.opacity(glowOpacity), radius: 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
            }
        }
    }
}

struct ActiveWorkoutView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @ObservedObject var workoutManager = WorkoutManager.shared
    
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
    @State private var showingFinishSheet = false
    @State private var elapsedSeconds: Int = 0
    @State private var selectedSetIndexMap: [String: Int] = [:] // exerciseId -> selectedSetIndex
    @State private var crownValue: Double = 0
    @State private var timerCancellable: Cancellable?
    let stopwatchTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        if let selected = selectedSetIndexMap[key] {
            return min(selected, exercise.setsState.count - 1)
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

    // MARK: - Sub-Views for Page 1 (Current Exercise)

    private func cardioControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let pc = selectedSetIdx < exercise.performedCardios.count ? exercise.performedCardios[selectedSetIdx] : nil
        let distance = pc?.distanceKm ?? 0.0
        let durationSec = pc?.durationSeconds ?? 0
        let durationMin = durationSec / 60

        return VStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISTÂNCIA")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                
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
                            .foregroundColor(.white)
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
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DURAÇÃO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                
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
                            .foregroundColor(.white)
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
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    Spacer()
                }
            }
        }
    }

    private func strengthControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let isFailure = selectedSetIdx < exercise.failureReport.count ? exercise.failureReport[selectedSetIdx] : false
        let failureRep = selectedSetIdx < exercise.failureReps.count ? exercise.failureReps[selectedSetIdx] : nil

        return VStack(spacing: 6) {
            HStack {
                Spacer()
                
                // Weight Info Block
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f kg", exercise.weight))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                
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
            
            // Compact Failure Toggle
            Button(action: {
                #if canImport(WatchKit)
                if !isFailure {
                    WKInterfaceDevice.current().play(.directionDown)
                } else {
                    WKInterfaceDevice.current().play(.click)
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

    private func currentExercisePageView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let exIndex = activeWorkout.currentExerciseIndex
        
        return ScrollView {
            if exIndex < activeWorkout.exercises.count {
                let exercise = activeWorkout.exercises[exIndex]
                let isCardio = exercise.muscle.lowercased().contains("cardio")
                
                VStack(alignment: .leading, spacing: 6) {
                    // Exercise Info Header with Navigation Chevrons
                    HStack(alignment: .center) {
                        Button(action: {
                            connectivityManager.changeExercise(to: exIndex - 1)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .disabled(exIndex == 0)
                        .opacity(exIndex == 0 ? 0.2 : 1.0)
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 32, height: 32)
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            HStack(spacing: 4) {
                                Text(exercise.muscle)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                if let exec = exercise.executionType, !exec.isEmpty {
                                    Text("•")
                                        .font(.system(size: 8))
                                        .foregroundColor(.gray)
                                    Text(exec)
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            connectivityManager.changeExercise(to: exIndex + 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .disabled(exIndex + 1 >= activeWorkout.exercises.count)
                        .opacity(exIndex + 1 >= activeWorkout.exercises.count ? 0.2 : 1.0)
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 4)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Vertical Sets List
                    let activeSetIdx = getSelectedSetIndex(for: exercise, index: exIndex)
                    VStack(spacing: 4) {
                        ForEach(0..<exercise.sets, id: \.self) { setIndex in
                            let isCompleted = setIndex < exercise.setsState.count ? exercise.setsState[setIndex] : false
                            let isSelected = setIndex == activeSetIdx
                            let isFailure = setIndex < exercise.failureReport.count ? exercise.failureReport[setIndex] : false
                            
                            Button(action: {
                                setSelectedSetIndex(for: exercise, index: exIndex, setIndex: setIndex)
                            }) {
                                HStack {
                                    Text("Série \(setIndex + 1)")
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? .orange : .white)
                                    
                                    Spacer()
                                    
                                    if isFailure && !isCardio {
                                        Image(systemName: "xmark.octagon.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.red)
                                            .padding(.trailing, 2)
                                    }
                                    
                                    if isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(isCardio ? .blue : .green)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.orange.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Controls Area
                    VStack(alignment: .leading, spacing: 8) {
                        if isCardio {
                            cardioControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: activeSetIdx)
                        } else {
                            strengthControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: activeSetIdx)
                        }
                        
                        // Solid Concluir Série Button
                        Button(action: {
                            let isCompleted = activeSetIdx < exercise.setsState.count ? exercise.setsState[activeSetIdx] : false
                            let isFailure = activeSetIdx < exercise.failureReport.count ? exercise.failureReport[activeSetIdx] : false
                            let failureRep = activeSetIdx < exercise.failureReps.count ? exercise.failureReps[activeSetIdx] : nil
                            let pc = activeSetIdx < exercise.performedCardios.count ? exercise.performedCardios[activeSetIdx] : nil
                            
                            #if canImport(WatchKit)
                            if !isCompleted {
                                if isFailure {
                                    WKInterfaceDevice.current().play(.directionDown)
                                } else {
                                    WKInterfaceDevice.current().play(.directionUp)
                                }
                            } else {
                                WKInterfaceDevice.current().play(.click)
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
                        }) {
                            let isCompleted = activeSetIdx < exercise.setsState.count ? exercise.setsState[activeSetIdx] : false
                            HStack {
                                Spacer()
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isCompleted ? .white : .black)
                                Text(isCompleted ? "SÉRIE CONCLUÍDA" : "CONCLUIR SÉRIE")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(isCompleted ? .white : .black)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(isCompleted ? Color.gray.opacity(0.3) : Color.green)
                            .cornerRadius(12)
                            .shadow(color: isCompleted ? Color.clear : Color.green.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 6)
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
        ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("TEMPO TOTAL")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    if isLuminanceReduced {
                        Text(formatDuration(elapsedSeconds))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    } else {
                        Text(formatDuration(elapsedSeconds))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(activeWorkout.paused ? .orange : .green)
                    }
                }
                .padding(.vertical, 4)
                
                // HealthKit Metrics
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 9))
                            Text("BATIMENTOS")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate)) bpm" : "-- bpm")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 9))
                            Text("CALORIAS")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        Text(workoutManager.activeCalories > 0 ? "\(Int(workoutManager.activeCalories)) kcal" : "-- kcal")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 6)
                
                Divider().background(Color.white.opacity(0.1))
                
                VStack(spacing: 6) {
                    // Pause/Resume Workout
                    Button(action: {
                        connectivityManager.togglePause(currentlyPaused: activeWorkout.paused)
                    }) {
                        HStack {
                            Image(systemName: activeWorkout.paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(activeWorkout.paused ? "Retomar Treino" : "Pausar Treino")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(activeWorkout.paused ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(activeWorkout.paused ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Adiar Treino (Postpone)
                    Button(action: {
                        connectivityManager.postponeWorkout()
                    }) {
                        HStack {
                            Image(systemName: "snooze")
                                .font(.system(size: 11, weight: .bold))
                            Text("Adiar Treino")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Finalizar Treino
                    Button(action: {
                        showingFinishSheet = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Finalizar Treino")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(.green)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Cancelar Treino
                    Button(action: {
                        showingCancelAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Cancelar Treino")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 4)
            }
        }
        .focusable()
        .focused($isControlsPageFocused)
        .onAppear {
            isControlsPageFocused = true
        }
    }


    
    private func handleCrownRotation(newValue: Double, oldValue: Double, activeWorkout: WatchActiveWorkoutState) {
        let delta = Int(newValue - oldValue)
        guard delta != 0 else { return }
        
        guard activeWorkout.currentExerciseIndex < activeWorkout.exercises.count else { return }
        let exercise = activeWorkout.exercises[activeWorkout.currentExerciseIndex]
        let isCardio = exercise.muscle.lowercased().contains("cardio")
        
        if isCardio {
            // Adjust cardio duration
            let currentDuration = exercise.reps
            let newDuration = max(10, currentDuration + delta * 5)
            connectivityManager.updateCardio(exerciseIndex: activeWorkout.currentExerciseIndex, setIndex: 0, distance: 0.0, duration: newDuration)
        } else {
            // Adjust weight
            let currentWeight = exercise.weight
            let newWeight = max(0, currentWeight + Double(delta) * 0.5)
            connectivityManager.updateExerciseWeightReps(exerciseIndex: activeWorkout.currentExerciseIndex, weight: newWeight, reps: exercise.reps)
        }
        
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    var body: some View {
        Group {
            if let activeWorkout = connectivityManager.activeWorkout {
                if let restTimer = activeWorkout.restTimer {
                    RestTimerView(restTimer: restTimer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView {
                        currentExercisePageView(activeWorkout: activeWorkout)
                        workoutControlsPageView(activeWorkout: activeWorkout)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .focusable()
                    .digitalCrownRotation($crownValue, from: 0, through: 100, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
                    .onChange(of: crownValue) { oldValue, newValue in
                        handleCrownRotation(newValue: newValue, oldValue: oldValue, activeWorkout: activeWorkout)
                    }
                    .onAppear {
                        timerCancellable = stopwatchTimer.sink { _ in
                            elapsedSeconds += 1
                        }
                    }
                    .onDisappear {
                        timerCancellable?.cancel()
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
        .onReceive(stopwatchTimer) { _ in
            if !isLuminanceReduced {
                updateStopwatch()
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
        guard let activeWorkout = connectivityManager.activeWorkout else { return }
        if activeWorkout.paused {
            elapsedSeconds = activeWorkout.elapsedSeconds
        } else {
            let currentTimeMs = Int64(Date().timeIntervalSince1970 * 1000)
            let diff = currentTimeMs - activeWorkout.startTime
            elapsedSeconds = max(0, Int(diff / 1000))
        }
    }
}
