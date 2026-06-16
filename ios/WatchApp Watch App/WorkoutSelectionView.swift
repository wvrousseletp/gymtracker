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
                    if connectivityManager.routines.isEmpty {
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
                    }
                }
            }
            .navigationTitle("Los Mooscles")
        }
    }
}
