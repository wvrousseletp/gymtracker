import SwiftUI

struct WorkoutSelectionView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared

    var body: some View {
        NavigationView {
            VStack {
                if let activeWorkout = connectivityManager.activeWorkout {
                    VStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        
                        Text("Treino em Andamento")
                            .font(.headline)
                        
                        Text(activeWorkout.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        NavigationLink(destination: ActiveWorkoutView()) {
                            Text("Retomar Treino")
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    if connectivityManager.routines.isEmpty && connectivityManager.library.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "hourglass.badge.plus")
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("Nenhum treino sincronizado")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Text("Abra o app no iPhone para enviar os treinos.")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            if !connectivityManager.routines.isEmpty {
                                Section(header: Text("Escolha um Treino")) {
                                    ForEach(connectivityManager.routines) { routine in
                                        Button(action: {
                                            connectivityManager.startWorkout(routineId: routine.id)
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(routine.name)
                                                        .font(.body)
                                                        .bold()
                                                    Text("\(routine.exercises.count) exercícios")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "play.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if !connectivityManager.library.isEmpty {
                                Section(header: Text("Exercícios Avulsos")) {
                                    ForEach(connectivityManager.library) { exercise in
                                        Button(action: {
                                            connectivityManager.startSingleExercise(exerciseId: exercise.id)
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(exercise.name)
                                                        .font(.body)
                                                        .bold()
                                                    Text(exercise.muscle)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Los Mooscles")
        }
    }
}
