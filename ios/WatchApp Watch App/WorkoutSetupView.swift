import SwiftUI

struct ExerciseSetupCard: View {
    let exercise: WatchRoutineExercise
    let name: String
    let isExpanded: Bool
    let onHeaderTap: () -> Void
    
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var weight: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onHeaderTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text("\(sets) séries")
                            Text("•")
                            Text("\(reps) reps")
                            Text("•")
                            Text(String(format: "%.1f kg", weight))
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider().background(Color.white.opacity(0.1))
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Séries").font(.system(size: 10, weight: .bold))
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                if sets > 1 { sets -= 1 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("\(sets)")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 20)
                            
                            Button(action: {
                                sets += 1
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    HStack {
                        Text("Reps").font(.system(size: 10, weight: .bold))
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                if reps > 1 { reps -= 1 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("\(reps)")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 20)
                            
                            Button(action: {
                                reps += 1
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    HStack {
                        Text("Carga").font(.system(size: 10, weight: .bold))
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                if weight >= 0.5 { weight -= 0.5 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(String(format: "%.1f", weight))
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 34, alignment: .center)
                            
                            Button(action: {
                                weight += 0.5
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isExpanded ? Color.orange.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct WorkoutSetupView: View {
    let routine: WatchRoutine
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared

    @State private var customSets: [String: Int] = [:]
    @State private var customReps: [String: Int] = [:]
    @State private var customWeights: [String: Double] = [:]
    
    @State private var expandedExerciseId: String? = nil

    init(routine: WatchRoutine) {
        self.routine = routine
    }

    private func getSets(for exercise: WatchRoutineExercise) -> Int {
        customSets[exercise.exerciseId] ?? exercise.sets
    }

    private func getReps(for exercise: WatchRoutineExercise) -> Int {
        customReps[exercise.exerciseId] ?? exercise.reps
    }

    private func getWeight(for exercise: WatchRoutineExercise) -> Double {
        customWeights[exercise.exerciseId] ?? exercise.weight
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("Configurar Treino")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    Text(routine.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.bottom, 6)

                ForEach(routine.exercises) { exercise in
                    let name = connectivityManager.library.first(where: { $0.id == exercise.exerciseId })?.name ?? "Exercício"
                    let isExpanded = expandedExerciseId == exercise.exerciseId
                    
                    let setsBinding = Binding<Int>(
                        get: { self.getSets(for: exercise) },
                        set: { self.customSets[exercise.exerciseId] = $0 }
                    )
                    let repsBinding = Binding<Int>(
                        get: { self.getReps(for: exercise) },
                        set: { self.customReps[exercise.exerciseId] = $0 }
                    )
                    let weightBinding = Binding<Double>(
                        get: { self.getWeight(for: exercise) },
                        set: { self.customWeights[exercise.exerciseId] = $0 }
                    )
                    
                    ExerciseSetupCard(
                        exercise: exercise,
                        name: name,
                        isExpanded: isExpanded,
                        onHeaderTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if isExpanded {
                                    self.expandedExerciseId = nil
                                } else {
                                    self.expandedExerciseId = exercise.exerciseId
                                }
                            }
                        },
                        sets: setsBinding,
                        reps: repsBinding,
                        weight: weightBinding
                    )
                }

                Button(action: {
                    var customMap: [[String: Any]] = []
                    for exercise in routine.exercises {
                        let sets = getSets(for: exercise)
                        let reps = getReps(for: exercise)
                        let weight = getWeight(for: exercise)
                        
                        customMap.append([
                            "exerciseId": exercise.exerciseId,
                            "sets": sets,
                            "reps": reps,
                            "weight": weight
                        ])
                    }
                    
                    connectivityManager.startWorkout(routineId: routine.id, customExercises: customMap)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Iniciar Treino")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
    }
}
