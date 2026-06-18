import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showingCancelAlert = false
    @State private var elapsedSeconds: Int = 0
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

    var body: some View {
        VStack(spacing: 0) {
            if let activeWorkout = connectivityManager.activeWorkout {

                // Cabeçalho: tempo + botões de controle
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

                // Timer de descanso inline
                if let restTimer = activeWorkout.restTimer {
                    RestTimerView(restTimer: restTimer)
                } else {
                    // Lista de exercícios
                    List {
                        Section(header: Text(activeWorkout.name).foregroundColor(.orange)) {
                            ForEach(0..<activeWorkout.exercises.count, id: \.self) { exIndex in
                                let exercise = activeWorkout.exercises[exIndex]
                                let isCurrent = exIndex == activeWorkout.currentExerciseIndex
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(isCurrent ? .orange : .white)
                                        Spacer()
                                        if isCurrent {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                        }
                                    }

                                    Text(exercise.muscle)
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Carga: \(exercise.weight, specifier: "%.1f") kg")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                            HStack(spacing: 6) {
                                                Button(action: {
                                                    let newWeight = max(0, exercise.weight - 0.5)
                                                    connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newWeight, reps: exercise.reps)
                                                }) {
                                                    Image(systemName: "minus.square.fill")
                                                        .font(.title3).foregroundColor(.blue)
                                                }
                                                .buttonStyle(PlainButtonStyle())

                                                Button(action: {
                                                    let newWeight = exercise.weight + 0.5
                                                    connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: newWeight, reps: exercise.reps)
                                                }) {
                                                    Image(systemName: "plus.square.fill")
                                                        .font(.title3).foregroundColor(.blue)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Reps: \(exercise.reps)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                            HStack(spacing: 6) {
                                                Button(action: {
                                                    let newReps = max(1, exercise.reps - 1)
                                                    connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newReps)
                                                }) {
                                                    Image(systemName: "minus.square.fill")
                                                        .font(.title3).foregroundColor(.blue)
                                                }
                                                .buttonStyle(PlainButtonStyle())

                                                Button(action: {
                                                    let newReps = exercise.reps + 1
                                                    connectivityManager.updateExerciseWeightReps(exerciseIndex: exIndex, weight: exercise.weight, reps: newReps)
                                                }) {
                                                    Image(systemName: "plus.square.fill")
                                                        .font(.title3).foregroundColor(.blue)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)

                                    // Séries
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                                                let isCompleted = setIndex < exercise.setsState.count ? exercise.setsState[setIndex] : false
                                                Button(action: {
                                                    connectivityManager.toggleSet(exerciseIndex: exIndex, setIndex: setIndex)
                                                }) {
                                                    VStack(spacing: 2) {
                                                        Text("S\(setIndex + 1)")
                                                            .font(.system(size: 10))
                                                            .bold()
                                                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                                            .font(.body)
                                                            .foregroundColor(isCompleted ? .green : .gray)
                                                    }
                                                    .padding(6)
                                                    .background(isCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                                    .cornerRadius(6)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.vertical, 4)
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
                        .foregroundColor(.gray)
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
            let diff = Int(Date().timeIntervalSince1970 * 1000) - activeWorkout.startTime
            elapsedSeconds = max(0, diff / 1000)
        }
    }
}
