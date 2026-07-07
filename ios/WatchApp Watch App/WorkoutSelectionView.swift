import SwiftUI

struct PlannedRoutineRow: View {
    let routine: WatchRoutine
    let item: PlannedWatchItem
    let isCompleted: Bool
    
    var body: some View {
        NavigationLink(destination: WorkoutSetupView(routine: routine)) {
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
        .accessibilityLabel(isCompleted ? "\(item.title), treino concluído" : "\(item.title), \(item.subtitle)")
        .accessibilityHint(isCompleted ? "Toque para ver detalhes" : "Toque para iniciar treino")
    }
}

struct PlannedExerciseRow: View {
    let exerciseId: String
    let item: PlannedWatchItem
    let isCompleted: Bool
    let onSingleExerciseTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            onSingleExerciseTap(exerciseId)
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
        .accessibilityLabel(isCompleted ? "\(item.title), exercício concluído" : "\(item.title), \(item.subtitle)")
        .accessibilityHint(isCompleted ? "Toque para ver detalhes" : "Toque para iniciar exercício")
    }
}

struct PlannedItemRow: View {
    let item: PlannedWatchItem
    let isCompleted: Bool
    let onSingleExerciseTap: (String) -> Void
    let routines: [WatchRoutine]
    
    var body: some View {
        if item.kind == .routine,
           let routineId = item.routineId,
           let routine = routines.first(where: { $0.id == routineId }) {
            PlannedRoutineRow(routine: routine, item: item, isCompleted: isCompleted)
        } else if item.kind == .singleExercise, let exerciseId = item.exerciseId {
            PlannedExerciseRow(exerciseId: exerciseId, item: item, isCompleted: isCompleted, onSingleExerciseTap: onSingleExerciseTap)
        } else {
            EmptyView()
        }
    }
}

struct RoutineRow: View {
    let routine: WatchRoutine
    let isCompleted: Bool
    
    var body: some View {
        NavigationLink(destination: WorkoutSetupView(routine: routine)) {
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
        .accessibilityLabel(isCompleted ? "\(routine.name), treino concluído" : "\(routine.name), \(routine.exercises.count) exercícios")
        .accessibilityHint(isCompleted ? "Toque para ver detalhes" : "Toque para configurar e iniciar treino")
    }
}

struct WorkoutSelectionView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var activeTab = 0

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
        TabView(selection: $activeTab) {
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
                                    Section(header: 
                                        HStack(spacing: 4) {
                                            Image(systemName: "snooze")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("TREINO ADIADO")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.yellow)
                                    ) {
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
                                    Section(header: 
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("TREINOS DE HOJE")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.green)
                                    ) {
                                        ForEach(todayPlannedItems) { item in
                                            let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(item.title)
                                            PlannedItemRow(
                                                item: item,
                                                isCompleted: isCompleted,
                                                onSingleExerciseTap: { exerciseId in
                                                    connectivityManager.startSingleExercise(exerciseId: exerciseId)
                                                },
                                                routines: connectivityManager.routines
                                            )
                                        }
                                    }
                                }

                                // Seção 1: Todos os Treinos
                                if !connectivityManager.routines.isEmpty {
                                    Section(header: 
                                        HStack(spacing: 4) {
                                            Image(systemName: "list.bullet")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("TODOS OS TREINOS")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.orange)
                                    ) {
                                        ForEach(connectivityManager.routines) { routine in
                                            let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(routine.name)
                                            RoutineRow(
                                                routine: routine,
                                                isCompleted: isCompleted
                                            )
                                        }
                                    }
                                }
                                
                                // Seção 2: Exercícios Avulsos
                                if !filteredLibrary.isEmpty {
                                    Section(header: 
                                        HStack(spacing: 4) {
                                            Image(systemName: "dumbbell.fill")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("EXERCÍCIOS AVULSOS")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.blue)
                                    ) {
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    connectivityManager.requestSync()
                }
            }
            .tag(0)

            // MARK: - Tab 2: Weekly Stats
            WeeklyStatsView()
                .tag(1)

            // MARK: - Tab 3: Water Tracker
            WatchWaterView()
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .onOpenURL { url in
            if url.host == "water" {
                activeTab = 2
            } else if url.host == "workouts" || url.host == "home" {
                activeTab = 0
            }
        }
    }
}

// MARK: - Water Tracker View Implementation

struct WatchWaterView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showRemoveSheet = false
    
    // Quick add presets
    let presets = [150, 250, 500]
    
    var progress: Double {
        let current = Double(connectivityManager.waterIntakeCurrent)
        let target = Double(connectivityManager.waterIntakeTarget)
        guard target > 0 else { return 0.0 }
        return min(current / target, 1.0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Circular Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.spring(), value: connectivityManager.waterIntakeCurrent)
                    
                    VStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text("\(connectivityManager.waterIntakeCurrent)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("de \(connectivityManager.waterIntakeTarget)ml")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 4)
                
                // Presets Grid
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { amount in
                            Button(action: {
                                let newTotal = connectivityManager.waterIntakeCurrent + amount
                                connectivityManager.updateWaterIntake(newAmountMl: newTotal)
                                #if os(watchOS)
                                WKInterfaceDevice.current().play(.click)
                                #endif
                            }) {
                                VStack(spacing: 2) {
                                    Text("+\(amount)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                    Text("ml")
                                        .font(.system(size: 7))
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Reset or Minus button for adjustments
                    if connectivityManager.waterIntakeCurrent > 0 {
                        Button(action: {
                            showRemoveSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 9))
                                Text("Remover...")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Água")
        .sheet(isPresented: $showRemoveSheet) {
            WatchWaterRemoveSheet(
                isPresented: $showRemoveSheet,
                maxAmount: connectivityManager.waterIntakeCurrent,
                onConfirm: { amount in
                    let newTotal = max(0, connectivityManager.waterIntakeCurrent - amount)
                    connectivityManager.updateWaterIntake(newAmountMl: newTotal)
                }
            )
        }
    }
}

struct WatchWaterRemoveSheet: View {
    @Binding var isPresented: Bool
    let maxAmount: Int
    let onConfirm: (Int) -> Void
    
    @State private var selectedAmount: Int = 150
    
    var options: [Int] {
        let step = 50
        let limit = min(maxAmount, 3000)
        if limit < step {
            return [50]
        }
        return stride(from: step, through: limit, by: step).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Remover Água")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.red)
                .padding(.top, 2)
            
            Picker("Quantidade", selection: $selectedAmount) {
                ForEach(options, id: \.self) { amount in
                    Text("\(amount) ml")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .tag(amount)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 55)
            
            HStack(spacing: 6) {
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancelar")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
                
                Button(action: {
                    onConfirm(selectedAmount)
                    isPresented = false
                }) {
                    Text("Remover")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 4)
        .onAppear {
            if maxAmount < 150 {
                selectedAmount = maxAmount > 0 ? (maxAmount / 50) * 50 : 50
                if selectedAmount == 0 { selectedAmount = 50 }
            } else {
                selectedAmount = 150
            }
        }
    }
}

