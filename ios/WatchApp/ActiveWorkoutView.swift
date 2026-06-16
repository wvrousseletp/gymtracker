import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showingCancelAlert = false
    @State private var activeRestTime: Int?
    @State private var showingRestTimer = false

    var body: some View {
        VStack {
            if let activeWorkout = connectivityManager.activeWorkout {
                List {
                    Section(header: Text(activeWorkout.name).foregroundColor(.orange)) {
                        ForEach(0..<activeWorkout.exercises.count, id: \.self) { exIndex in
                            let exercise = activeWorkout.exercises[exIndex]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("\(exercise.muscle) • \(exercise.weight, specifier: "%.1f") kg")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(0..<exercise.sets, id: \.self) { setIndex in
                                            let isCompleted = setIndex < exercise.setsState.count ? exercise.setsState[setIndex] : false
                                            Button(action: {
                                                connectivityManager.toggleSet(exerciseIndex: exIndex, setIndex: setIndex)
                                                
                                                // Se completou a série, ativa o tempo de descanso
                                                if !isCompleted {
                                                    activeRestTime = exercise.rest
                                                    showingRestTimer = true
                                                }
                                            }) {
                                                VStack {
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
                .sheet(isPresented: $showingRestTimer) {
                    if let restTime = activeRestTime {
                        RestTimerView(durationSeconds: restTime, isPresented: $showingRestTimer)
                    }
                }
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
            } else {
                Text("Nenhum treino ativo")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Treino")
    }
}
