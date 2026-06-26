import SwiftUI

struct WorkoutSelectionView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared

    private var todayPlannedItems: [PlannedWatchItem] {
        WatchPlannerHelper.resolveTodayPlannedItems(
            routines: connectivityManager.routines,
            library: connectivityManager.library,
            planner: connectivityManager.planner
        )
    }

    private var filteredLibrary: [WatchLibraryExercise] {
        WatchPlannerHelper.filteredLibraryForWatch(
            library: connectivityManager.library,
            planner: connectivityManager.planner
        )
    }

    var body: some View {
        TabView {
            // MARK: - Tab 1: Workout Selection
            NavigationView {
                VStack {
                    if let activeWorkout = connectivityManager.activeWorkout, !activeWorkout.postponed {
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
                                if !connectivityManager.isReachable {
                                    Section {
                                        HStack(spacing: 6) {
                                            Image(systemName: "wifi.slash")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.yellow)
                                            Text("Modo Offline Ativo")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.yellow)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 2)
                                    }
                                }

                                // Seção 0: Treino Adiado em Andamento
                                if let activeWorkout = connectivityManager.activeWorkout, activeWorkout.postponed {
                                    Section(header: Text("Treino Adiado").font(.system(size: 10, weight: .bold)).foregroundColor(.yellow)) {
                                        Button(action: {
                                            connectivityManager.resumeWorkout()
                                        }) {
                                            HStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.yellow.opacity(0.12))
                                                        .frame(width: 24, height: 24)
                                                    Image(systemName: "snooze")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.yellow)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(activeWorkout.name)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                    Text("Retomar Treino")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.yellow)
                                                }
                                                Spacer()
                                                Image(systemName: "arrow.forward.circle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.yellow)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(8)
                                        .background(Color.yellow.opacity(0.04))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.yellow.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                }

                                // Seção 0.1: Treinos Planejados para Hoje
                                if !todayPlannedItems.isEmpty {
                                    Section(header: Text("Treinos de Hoje").font(.system(size: 10, weight: .bold)).foregroundColor(.green)) {
                                        ForEach(todayPlannedItems) { item in
                                            let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(item.title)
                                            Button(action: {
                                                switch item.kind {
                                                case .routine:
                                                    if let routineId = item.routineId {
                                                        connectivityManager.startWorkout(routineId: routineId)
                                                    }
                                                case .singleExercise:
                                                    if let exerciseId = item.exerciseId {
                                                        connectivityManager.startSingleExercise(exerciseId: exerciseId)
                                                    }
                                                }
                                            }) {
                                                HStack(spacing: 8) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isCompleted ? Color.green.opacity(0.12) : Color.green.opacity(0.12))
                                                            .frame(width: 24, height: 24)
                                                        Image(systemName: isCompleted ? "checkmark.seal.fill" : "calendar")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(isCompleted ? .green : .green)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(item.title)
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(isCompleted ? .gray : .white)
                                                            .strikethrough(isCompleted, color: .gray)
                                                        Text(isCompleted ? "Treino concluído hoje" : item.subtitle)
                                                            .font(.system(size: 9))
                                                            .foregroundColor(isCompleted ? .green.opacity(0.8) : .gray)
                                                    }
                                                    Spacer()
                                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "play.fill")
                                                        .font(.system(size: isCompleted ? 12 : 8))
                                                        .foregroundColor(isCompleted ? .green : .green)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(8)
                                            .background(isCompleted ? Color.black.opacity(0.2) : Color.green.opacity(0.04))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isCompleted ? Color.green.opacity(0.2) : Color.green.opacity(0.15), lineWidth: 1)
                                            )
                                        }
                                    }
                                }

                                // Seção 1: Todos os Treinos
                                if !connectivityManager.routines.isEmpty {
                                    Section(header: Text("Todos os Treinos").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)) {
                                        ForEach(connectivityManager.routines) { routine in
                                            let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(routine.name)
                                            Button(action: {
                                                connectivityManager.startWorkout(routineId: routine.id)
                                            }) {
                                                HStack(spacing: 8) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isCompleted ? Color.green.opacity(0.12) : Color.green.opacity(0.12))
                                                            .frame(width: 24, height: 24)
                                                        Image(systemName: isCompleted ? "checkmark.seal.fill" : "play.fill")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(isCompleted ? .green : .green)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(routine.name)
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(isCompleted ? .gray : .white)
                                                            .strikethrough(isCompleted, color: .gray)
                                                        Text(isCompleted ? "Treino concluído hoje" : "\(routine.exercises.count) exercícios")
                                                            .font(.system(size: 9))
                                                            .foregroundColor(isCompleted ? .green.opacity(0.8) : .gray)
                                                    }
                                                    Spacer()
                                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "chevron.right")
                                                        .font(.system(size: isCompleted ? 12 : 8, weight: .bold))
                                                        .foregroundColor(isCompleted ? .green : .gray)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(8)
                                            .background(isCompleted ? Color.black.opacity(0.2) : Color.white.opacity(0.04))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isCompleted ? Color.green.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                
                                // Seção 2: Exercícios Avulsos
                                if !filteredLibrary.isEmpty {
                                    Section(header: Text("Exercícios Avulsos").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)) {
                                        ForEach(filteredLibrary) { exercise in
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

            // MARK: - Tab 2: Weekly Stats
            WeeklyStatsView()
        }
        .tabViewStyle(PageTabViewStyle())
    }
}
