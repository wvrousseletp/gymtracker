import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showingCancelAlert = false
    @State private var elapsedSeconds: Int = 0
    @State private var focusedExerciseIndex: Int? = nil
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

    // MARK: - Sub-Views

    private func headerView(activeWorkout: WatchActiveWorkoutState) -> some View {
        HStack(spacing: 8) {
            // Tempo Decorrido Dashboard
            VStack(alignment: .leading, spacing: -2) {
                Text("DURAÇÃO")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray)
                Text(formatDuration(elapsedSeconds))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(activeWorkout.paused ? .orange : .green)
            }
            
            Spacer()
            
            // Controles de Pausa e Descanso
            HStack(spacing: 6) {
                if activeWorkout.restTimer != nil {
                    Button(action: {
                        connectivityManager.skipRest()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    connectivityManager.togglePause(currentlyPaused: activeWorkout.paused)
                }) {
                    Image(systemName: activeWorkout.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(activeWorkout.paused ? Color.green : Color.orange)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.bottom, 6)
    }

    private func setSelectorView(exercise: WatchActiveExercise, exIndex: Int, isCardio: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    let isCompleted = setIndex < exercise.setsState.count ? exercise.setsState[setIndex] : false
                    let isSelected = setIndex == getSelectedSetIndex(for: exercise, index: exIndex)
                    let isFailure = setIndex < exercise.failureReport.count ? exercise.failureReport[setIndex] : false

                    Button(action: {
                        setSelectedSetIndex(for: exercise, index: exIndex, setIndex: setIndex)
                    }) {
                        VStack(spacing: 2) {
                            Text(isCardio ? "S\(setIndex + 1)" : "S\(setIndex + 1)")
                                .font(.system(size: 8, weight: isSelected ? .black : .regular))
                                .foregroundColor(isSelected ? .orange : .white)
                            
                            ZStack {
                                Circle()
                                    .fill(isCompleted ? (isCardio ? Color.blue.opacity(0.15) : Color.green.opacity(0.15)) : Color.white.opacity(0.04))
                                    .frame(width: 22, height: 22)
                                
                                if isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(isCardio ? .blue : .green)
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        .frame(width: 20, height: 20)
                                }
                                
                                if isFailure && !isCardio {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .heavy))
                                        .foregroundColor(.red)
                                        .frame(width: 14, height: 14)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(5)
                        .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func cardioControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let pc = selectedSetIdx < exercise.performedCardios.count ? exercise.performedCardios[selectedSetIdx] : nil
        let distance = pc?.distanceKm ?? 0.0
        let durationSec = pc?.durationSeconds ?? 0
        let durationMin = durationSec / 60

        return HStack(spacing: 8) {
            // Stepper de Distância Compacto (Estilo Pill)
            HStack(spacing: 4) {
                Button(action: {
                    let newDist = max(0.0, distance - 0.1)
                    connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: -1) {
                    Text("DIST")
                        .font(.system(size: 7))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(minWidth: 44)
                
                Button(action: {
                    let newDist = distance + 0.1
                    connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Spacer(minLength: 0)

            // Stepper de Tempo Compacto (Estilo Pill)
            HStack(spacing: 4) {
                Button(action: {
                    let newDur = max(0, durationMin - 1)
                    connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: -1) {
                    Text("MIN")
                        .font(.system(size: 7))
                        .foregroundColor(.gray)
                    Text("\(durationMin) m")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(minWidth: 40)
                
                Button(action: {
                    let newDur = durationMin + 1
                    connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func strengthControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let isFailure = selectedSetIdx < exercise.failureReport.count ? exercise.failureReport[selectedSetIdx] : false
        let failureRep = selectedSetIdx < exercise.failureReps.count ? exercise.failureReps[selectedSetIdx] : nil

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Stepper de Carga (Estilo Pill)
                HStack(spacing: 4) {
                    Button(action: {
                        let newW = max(0.0, exercise.weight - 0.5)
                        connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(spacing: -1) {
                        Text("CARGA")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f kg", exercise.weight))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(minWidth: 44)
                    
                    Button(action: {
                        let newW = exercise.weight + 0.5
                        connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                Spacer(minLength: 0)

                // Stepper de Repetições (Estilo Pill)
                HStack(spacing: 4) {
                    Button(action: {
                        let newR = max(1, exercise.reps - 1)
                        connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(spacing: -1) {
                        Text(exercise.measurementType == "time" ? "TEMPO" : "REPS")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                        Text(exercise.measurementType == "time" ? "\(exercise.reps)s" : "\(exercise.reps)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(minWidth: 40)
                    
                    Button(action: {
                        let newR = exercise.reps + 1
                        connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }

            // Botão Falha Muscular + Mini Stepper de Repetições de Falha
            HStack(spacing: 6) {
                Button(action: {
                    connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: !isFailure, failureRep: failureRep)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isFailure ? "xmark.octagon.fill" : "xmark.octagon")
                            .font(.system(size: 9))
                        Text(isFailure ? "Falhou" : "Falha")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(isFailure ? .red : .gray)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(isFailure ? Color.red.opacity(0.12) : Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFailure ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if isFailure {
                    Spacer(minLength: 2)

                    HStack(spacing: 4) {
                        Button(action: {
                            let current = failureRep ?? exercise.reps
                            let newR = max(1, current - 1)
                            connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                        }) {
                            Image(systemName: "minus.square.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("R:\(failureRep ?? exercise.reps)")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                            .frame(width: 26, alignment: .center)

                        Button(action: {
                            let current = failureRep ?? exercise.reps
                            let newR = current + 1
                            connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                        }) {
                            Image(systemName: "plus.square.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(.top, 2)
        }
    }

    private func exerciseRowView(activeWorkout: WatchActiveWorkoutState, exIndex: Int) -> some View {
        let exercise = activeWorkout.exercises[exIndex]
        let isCurrent = exIndex == activeWorkout.currentExerciseIndex
        let isExpanded = (focusedExerciseIndex == nil && isCurrent) || focusedExerciseIndex == exIndex
        let completedCount = exercise.setsState.filter { $0 }.count
        let isCardio = exercise.muscle.lowercased().contains("cardio")

        return VStack(alignment: .leading, spacing: 4) {
            // Cabeçalho do Card
            Button(action: {
                withAnimation {
                    focusedExerciseIndex = isExpanded ? -1 : exIndex
                }
            }) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(exercise.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isCurrent ? .orange : .white)
                            .lineLimit(1)
                        
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
                    
                    // Badge de progresso compacto
                    Text("\(completedCount)/\(exercise.sets)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(completedCount == exercise.sets ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(completedCount == exercise.sets ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                        .cornerRadius(6)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 3)

                // 1. Horizontal Scroll de Séries
                setSelectorView(exercise: exercise, exIndex: exIndex, isCardio: isCardio)

                // 2. Controles de Detalhes da Série Selecionada
                let selectedSetIdx = getSelectedSetIndex(for: exercise, index: exIndex)
                let isCompleted = selectedSetIdx < exercise.setsState.count ? exercise.setsState[selectedSetIdx] : false

                VStack(alignment: .leading, spacing: 8) {
                    if isCardio {
                        cardioControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: selectedSetIdx)
                    } else {
                        strengthControls(exercise: exercise, exIndex: exIndex, selectedSetIdx: selectedSetIdx)
                    }

                    // 3. Botão Concluir Série Glassmorphic
                    Button(action: {
                        let isFailure = selectedSetIdx < exercise.failureReport.count ? exercise.failureReport[selectedSetIdx] : false
                        let failureRep = selectedSetIdx < exercise.failureReps.count ? exercise.failureReps[selectedSetIdx] : nil
                        let pc = selectedSetIdx < exercise.performedCardios.count ? exercise.performedCardios[selectedSetIdx] : nil
                        
                        connectivityManager.toggleSet(
                            exerciseIndex: exIndex,
                            setIndex: selectedSetIdx,
                            isDone: !isCompleted,
                            isFailure: isFailure,
                            failureRep: failureRep,
                            distance: pc?.distanceKm,
                            duration: pc?.durationSeconds
                        )
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10))
                                .foregroundColor(isCompleted ? .green : .white)
                            Text(isCompleted ? "Série Concluída" : "Concluir Série")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isCompleted ? .green : .white)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(isCompleted ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isCompleted ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? Color.orange.opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1)
        )
        .padding(.vertical, 2)
    }

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            if let activeWorkout = connectivityManager.activeWorkout {
                // Cabeçalho: tempo + botões de controle
                headerView(activeWorkout: activeWorkout)

                // Timer de descanso inline
                if let restTimer = activeWorkout.restTimer {
                    RestTimerView(restTimer: restTimer)
                } else {
                    // Lista de exercícios
                    List {
                        Section(header: Text(activeWorkout.name).font(.system(size: 9, weight: .bold)).foregroundColor(.orange)) {
                            ForEach(0..<activeWorkout.exercises.count, id: \.self) { exIndex in
                                exerciseRowView(activeWorkout: activeWorkout, exIndex: exIndex)
                            }
                        }

                        Section {
                            Button(action: {
                                connectivityManager.completeWorkout()
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 10))
                                    Text("Finalizar Treino")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                            }

                            Button(action: {
                                showingCancelAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 10))
                                    Text("Cancelar Treino")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .listStyle(.carousel)
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
        .navigationTitle("Treino")
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
            if let activeWorkout = connectivityManager.activeWorkout {
                focusedExerciseIndex = activeWorkout.currentExerciseIndex
            }
        }
        .onReceive(stopwatchTimer) { _ in
            updateStopwatch()
        }
        .onChange(of: connectivityManager.activeWorkout?.currentExerciseIndex) { newIndex in
            if let index = newIndex {
                focusedExerciseIndex = index
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
