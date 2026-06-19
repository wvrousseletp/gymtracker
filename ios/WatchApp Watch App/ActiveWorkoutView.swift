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
        // Fallback to first uncompleted set
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
        VStack(spacing: 4) {
            Text(formatDuration(elapsedSeconds))
                .font(.title3)
                .bold()
                .foregroundColor(activeWorkout.paused ? .orange : .white)

            if activeWorkout.paused {
                Text("PAUSADO")
                    .font(.system(size: 9))
                    .bold()
                    .foregroundColor(.orange)
            }

            HStack(spacing: 12) {
                // Botão pausa / retomar
                Button(action: {
                    connectivityManager.togglePause(currentlyPaused: activeWorkout.paused)
                }) {
                    Image(systemName: activeWorkout.paused ? "play.fill" : "pause.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(activeWorkout.paused ? Color.green : Color.orange)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Botão pular descanso (só visível quando há timer)
                if activeWorkout.restTimer != nil {
                    Button(action: {
                        connectivityManager.skipRest()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
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
                            Text(isCardio ? "Sessão \(setIndex + 1)" : "S\(setIndex + 1)")
                                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .orange : .white)
                            
                            ZStack {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(isCompleted ? .green : .gray)
                                
                                if isFailure && !isCardio {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(6)
                        .background(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.02))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.bottom, 6)
    }

    private func cardioControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let pc = selectedSetIdx < exercise.performedCardios.count ? exercise.performedCardios[selectedSetIdx] : nil
        let distance = pc?.distanceKm ?? 0.0
        let durationSec = pc?.durationSeconds ?? 0
        let durationMin = durationSec / 60

        return HStack {
            // Stepper de Distância
            VStack {
                Text("Distância")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Text(String(format: "%.1f km", distance))
                    .font(.system(size: 11, weight: .bold))
                HStack(spacing: 4) {
                    Button(action: {
                        let newDist = max(0.0, distance - 0.1)
                        connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3).foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        let newDist = distance + 0.1
                        connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: newDist, duration: durationSec)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3).foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Spacer()

            // Stepper de Duração
            VStack {
                Text("Duração")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Text("\(durationMin) min")
                    .font(.system(size: 11, weight: .bold))
                HStack(spacing: 4) {
                    Button(action: {
                        let newDur = max(0, durationMin - 1)
                        connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3).foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        let newDur = durationMin + 1
                        connectivityManager.updateCardio(exerciseIndex: exIndex, setIndex: selectedSetIdx, distance: distance, duration: newDur * 60)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3).foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func strengthControls(exercise: WatchActiveExercise, exIndex: Int, selectedSetIdx: Int) -> some View {
        let isFailure = selectedSetIdx < exercise.failureReport.count ? exercise.failureReport[selectedSetIdx] : false
        let failureRep = selectedSetIdx < exercise.failureReps.count ? exercise.failureReps[selectedSetIdx] : nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Stepper de Carga
                VStack {
                    Text("Carga")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f kg", exercise.weight))
                        .font(.system(size: 11, weight: .bold))
                    HStack(spacing: 4) {
                        Button(action: {
                            let newW = max(0.0, exercise.weight - 0.5)
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            let newW = exercise.weight + 0.5
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newW, reps: exercise.reps)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer()

                // Stepper de Repetições
                VStack {
                    Text(exercise.measurementType == "time" ? "Tempo" : "Reps")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    Text(exercise.measurementType == "time" ? "\(exercise.reps)s" : "\(exercise.reps)")
                        .font(.system(size: 11, weight: .bold))
                    HStack(spacing: 4) {
                        Button(action: {
                            let newR = max(1, exercise.reps - 1)
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            let newR = exercise.reps + 1
                            connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newR)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 4)

            // Botão Falha Muscular
            HStack {
                Button(action: {
                    connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: !isFailure, failureRep: failureRep)
                }) {
                    HStack {
                        Image(systemName: isFailure ? "xmark.octagon.fill" : "xmark.octagon")
                        Text(isFailure ? "Falhou" : "Falha Muscular")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isFailure ? .red : .white.opacity(0.7))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(isFailure ? Color.red.opacity(0.15) : Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                if isFailure {
                    Spacer()

                    HStack(spacing: 4) {
                        Text("Rep:")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                        Text("\(failureRep ?? exercise.reps)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)

                        Button(action: {
                            let current = failureRep ?? exercise.reps
                            let newR = max(1, current - 1)
                            connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                        }) {
                            Image(systemName: "minus.square.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            let current = failureRep ?? exercise.reps
                            let newR = current + 1
                            connectivityManager.updateFailure(exerciseIndex: exIndex, setIndex: selectedSetIdx, isFailure: true, failureRep: newR)
                        }) {
                            Image(systemName: "plus.square.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func exerciseRowView(activeWorkout: WatchActiveWorkoutState, exIndex: Int) -> some View {
        let exercise = activeWorkout.exercises[exIndex]
        let isCurrent = exIndex == activeWorkout.currentExerciseIndex
        let isExpanded = (focusedExerciseIndex == nil && isCurrent) || focusedExerciseIndex == exIndex
        let completedCount = exercise.setsState.filter { $0 }.count
        let isCardio = exercise.muscle.lowercased().contains("cardio")

        return VStack(alignment: .leading, spacing: 4) {
            // Cabeçalho do Card de Exercício (Sempre visível)
            Button(action: {
                withAnimation {
                    focusedExerciseIndex = isExpanded ? -1 : exIndex // Toggle expand
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isCurrent ? .orange : .white)
                        
                        HStack(spacing: 4) {
                            Text(exercise.muscle)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            if let exec = exercise.executionType, !exec.isEmpty {
                                Text("•")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                Text(exec)
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue)
                            }
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Text("\(completedCount)/\(exercise.sets) concluídas")
                                .font(.system(size: 9))
                                .foregroundColor(completedCount == exercise.sets ? .green : .gray)
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(isCurrent ? .orange : .gray)
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()
                    .padding(.vertical, 4)

                // 1. Grid/Carrossel horizontal de séries/sessões
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

                    // 3. Botão Concluir Série (Checkmark grande)
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
                            Image(systemName: isCompleted ? "checkmark.seal.fill" : "checkmark.seal")
                                .foregroundColor(isCompleted ? .green : .white)
                            Text(isCompleted ? "Série Concluída" : "Concluir Série")
                                .foregroundColor(isCompleted ? .green : .white)
                                .bold()
                            Spacer()
                        }
                        .font(.system(size: 11))
                        .padding(.vertical, 6)
                        .background(isCompleted ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
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
                        Section(header: Text(activeWorkout.name).foregroundColor(.orange)) {
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
                                    Text("Finalizar Treino")
                                        .bold()
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                            }

                            Button(action: {
                                showingCancelAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Cancelar Treino")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
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
