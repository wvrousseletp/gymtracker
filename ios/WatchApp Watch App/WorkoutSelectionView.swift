import SwiftUI

struct WorkoutSelectionView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared

    var body: some View {
        NavigationView {
            VStack {
                if let activeWorkout = connectivityManager.activeWorkout {
                    ActiveWorkoutView()
                } else {
                    if connectivityManager.routines.isEmpty && connectivityManager.library.isEmpty {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "hourglass.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Nenhum treino sincronizado")
                                    .font(.system(size: 11, weight: .bold))
                                    .multilineTextAlignment(.center)
                                Text("Abra o app no iPhone para sincronizar.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding()
                    } else {
                        List {
                            if !connectivityManager.routines.isEmpty {
                                Section(header: Text("Escolha um Treino").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)) {
                                    ForEach(connectivityManager.routines) { routine in
                                        Button(action: {
                                            connectivityManager.startWorkout(routineId: routine.id)
                                        }) {
                                            HStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.green.opacity(0.12))
                                                        .frame(width: 24, height: 24)
                                                    Image(systemName: "play.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.green)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(routine.name)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                    Text("\(routine.exercises.count) exercícios")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(8)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            
                            if !connectivityManager.library.isEmpty {
                                Section(header: Text("Exercícios Avulsos").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)) {
                                    ForEach(connectivityManager.library) { exercise in
                                        Button(action: {
                                            connectivityManager.startSingleExercise(exerciseId: exercise.id)
                                        }) {
                                            HStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.blue.opacity(0.12))
                                                        .frame(width: 24, height: 24)
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(exercise.name)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                    Text(exercise.muscle)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(8)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .listStyle(.carousel)
                    }
                }
            }
            .navigationTitle("Los Mooscles")
            .onAppear {
                connectivityManager.requestSync()
            }
        }
    }
}
