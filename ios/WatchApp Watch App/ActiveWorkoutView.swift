import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct ActiveWorkoutView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showingCancelAlert = false
    @State private var elapsedSeconds: Int = 0
    @State private var selectedSetIndexMap: [String: Int] = [:] // exerciseId -> selectedSetIndex
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
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
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
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
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

        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CARGA")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            let newW = max(0.0, exercise.weight - 0.5)
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(String(format: "%.1f kg", exercise.weight))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(minWidth: 48, alignment: .center)
                        
                        Button(action: {
                            let newW = exercise.weight + 0.5
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
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
                Text(exercise.measurementType == "time" ? "TEMPO" : "REPS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            let newR = max(1, exercise.reps - 1)
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(exercise.measurementType == "time" ? "\(exercise.reps)s" : "\(exercise.reps)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(minWidth: 48, alignment: .center)
                        
                        Button(action: {
                            let newR = exercise.reps + 1
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
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

            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: !isFailure, failureRep: failureRep)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isFailure ? "xmark.octagon.fill" : "xmark.octagon")
                            .font(.system(size: 9))
                        Text(isFailure ? "Falhou" : "Registrar Falha")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(isFailure ? .red : .gray)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(isFailure ? Color.red.opacity(0.12) : Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFailure ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

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
                                        .frame(width: 24, height: 24)
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
                                        .frame(width: 24, height: 24)
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
            .padding(.top, 2)
        }
    }

    private func currentExercisePageView(activeWorkout: WatchActiveWorkoutState) -> some View {
        let exIndex = activeWorkout.currentExerciseIndex
        
        return ScrollView {
            if exIndex < activeWorkout.exercises.count {
                let exercise = activeWorkout.exercises[exIndex]
                let isCardio = exercise.muscle.lowercased().contains("cardio")
                
                VStack(alignment: .leading, spacing: 6) {
                    // Exercise Info Header
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.leading)
                        
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
                                WKInterfaceDevice.current().play(.success)
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
        .focusable(true)
    }

    private func workoutControlsPageView(activeWorkout: WatchActiveWorkoutState) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("TEMPO TOTAL")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text(formatDuration(elapsedSeconds))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(activeWorkout.paused ? .orange : .green)
                }
                .padding(.vertical, 8)
                
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
                        connectivityManager.completeWorkout()
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
        .focusable(true)
    }

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            if let activeWorkout = connectivityManager.activeWorkout {
                if let restTimer = activeWorkout.restTimer {
                    RestTimerView(restTimer: restTimer)
                } else {
                    TabView {
                        currentExercisePageView(activeWorkout: activeWorkout)
                        workoutControlsPageView(activeWorkout: activeWorkout)
                    }
                    .tabViewStyle(PageTabViewStyle())
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
        .onAppear {
            connectivityManager.requestSync()
            updateStopwatch()
        }
        .onReceive(stopwatchTimer) { _ in
            updateStopwatch()
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
