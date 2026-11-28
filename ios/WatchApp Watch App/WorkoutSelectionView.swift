import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct PlannedRoutineRow: View {
    let routine: WatchRoutine
    let item: PlannedWatchItem
    let isCompleted: Bool
    let onStartTap: (String) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                #if canImport(WatchKit)
                WatchHapticManager.shared.play(.light)
                #endif
                onStartTap(routine.id)
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 24, height: 24)
                        Image(systemName: isCompleted ? "checkmark.seal.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isCompleted ? .gray : .white)
                            .strikethrough(isCompleted, color: .gray)
                            .lineLimit(1)
                        Text(isCompleted ? "Treino concluído hoje" : item.subtitle)
                            .font(.system(size: 9))
                            .foregroundColor(isCompleted ? .green.opacity(0.8) : .gray)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(destination: WorkoutSetupView(routine: routine)) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Configurar \(item.title)")
        }
        .padding(8)
        .background(isCompleted ? Color.black.opacity(0.2) : Color.green.opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCompleted ? Color.green.opacity(0.2) : Color.green.opacity(0.22), lineWidth: 1)
        )
        .accessibilityLabel(isCompleted ? "\(item.title), treino concluído" : "\(item.title), \(item.subtitle)")
        .accessibilityHint("Toque para iniciar treino em 1 toque")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
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
                        .transition(.scale.combined(with: .opacity))
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
                    .transition(.scale.combined(with: .opacity))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
    }
}

struct PlannedItemRow: View {
    let item: PlannedWatchItem
    let isCompleted: Bool
    let onRoutineStartTap: (String) -> Void
    let onSingleExerciseTap: (String) -> Void
    let routines: [WatchRoutine]
    
    var body: some View {
        if item.kind == .routine,
           let routineId = item.routineId,
           let routine = routines.first(where: { $0.id == routineId }) {
            PlannedRoutineRow(routine: routine, item: item, isCompleted: isCompleted, onStartTap: onRoutineStartTap)
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
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    @StateObject var workoutManager = WorkoutManager.shared
    @State private var activeTab = 0
    @State private var showAllWorkouts = false
    @State private var favoriteRoutineIds: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "favorite_routines") ?? []
    )

    private var todayPlannedItems: [PlannedWatchItem] {
        WatchPlannerHelper.resolveTodayPlannedItems(
            routines: connectivityManager.routines,
            library: connectivityManager.library,
            planner: connectivityManager.planner
        )
    }
    
    private var sortedRoutines: [WatchRoutine] {
        let favs = connectivityManager.routines.filter { favoriteRoutineIds.contains($0.id) }
        let rest = connectivityManager.routines.filter { !favoriteRoutineIds.contains($0.id) }
        return favs + rest
    }
    
    private func toggleFavorite(routineId: String) {
        if favoriteRoutineIds.contains(routineId) {
            favoriteRoutineIds.remove(routineId)
        } else {
            favoriteRoutineIds.insert(routineId)
        }
        UserDefaults.standard.set(Array(favoriteRoutineIds), forKey: "favorite_routines")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var syncingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Sincronizando...")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var emptySyncView: some View {
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
    }

    @ViewBuilder
    private var offlineWarningSection: some View {
        let pendingCount = WatchLocalWorkoutManager.shared.getPendingSyncWorkouts().count
        if !connectivityManager.isReachable || pendingCount > 0 {
            Section {
                VStack(spacing: 6) {
                    if !connectivityManager.isReachable {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("Modo Offline Ativo")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                    if pendingCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("\(pendingCount) treino\(pendingCount > 1 ? "s" : "") aguardando iPhone")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            if connectivityManager.isReachable {
                                Button(action: {
                                    #if canImport(WatchKit)
                                    WatchHapticManager.shared.play(.light)
                                    #endif
                                    connectivityManager.syncOfflineWorkouts()
                                }) {
                                    Text("Enviar")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.cyan)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func postponedWorkoutSection(activeWorkout: WatchActiveWorkoutState) -> some View {
        if activeWorkout.postponed {
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
    }

    @ViewBuilder
    private var todayPlannedSection: some View {
        Section(header: 
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 8, weight: .bold))
                Text("TREINOS DE HOJE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundColor(.green)
        ) {
            if !todayPlannedItems.isEmpty {
                ForEach(todayPlannedItems) { item in
                    let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(item.title)
                    PlannedItemRow(
                        item: item,
                        isCompleted: isCompleted,
                        onRoutineStartTap: { routineId in
                            connectivityManager.startWorkout(routineId: routineId)
                        },
                        onSingleExerciseTap: { exerciseId in
                            connectivityManager.startSingleExercise(exerciseId: exerciseId)
                        },
                        routines: connectivityManager.routines
                    )
                }
            } else {
                HStack {
                    Spacer()
                    Text("Nenhum treino agendado hoje")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var allWorkoutsToggleButtonSection: some View {
        Section {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showAllWorkouts.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text("Todos os treinos")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showAllWorkouts ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
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

    @ViewBuilder
    private var routinesSection: some View {
        if !sortedRoutines.isEmpty {
            Section(header: 
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .bold))
                    Text("TODOS OS TREINOS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
            ) {
                ForEach(sortedRoutines) { routine in
                    let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(routine.name)
                    let isFavorite = favoriteRoutineIds.contains(routine.id)
                    
                    RoutineSelectionRow(
                        routine: routine,
                        isCompleted: isCompleted,
                        isFavorite: isFavorite,
                        onFavoriteToggle: {
                            toggleFavorite(routineId: routine.id)
                        }
                    )
                }
            }
        } else {
            Section {
                HStack {
                    Spacer()
                    Text("Nenhum treino encontrado")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var workoutContentList: some View {
        List {
            offlineWarningSection
            if let activeWorkout = connectivityManager.activeWorkout {
                postponedWorkoutSection(activeWorkout: activeWorkout)
            }
            todayPlannedSection
            allWorkoutsToggleButtonSection
            if showAllWorkouts {
                routinesSection
            }
        }
        .listStyle(.carousel)
    }

    @ViewBuilder
    private var workoutTabContent: some View {
        if let activeWorkout = connectivityManager.activeWorkout, !activeWorkout.postponed {
            ActiveWorkoutView()
        } else if workoutManager.workoutSessionState == .running || workoutManager.workoutSessionState == .paused || workoutManager.isLaunchedByiOS {
            VStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
                Text("Iniciando Treino...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .scaleEffect(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        } else if connectivityManager.isSyncing && connectivityManager.routines.isEmpty && connectivityManager.library.isEmpty {
            syncingView
        } else if connectivityManager.routines.isEmpty && connectivityManager.library.isEmpty {
            emptySyncView
        } else {
            workoutContentList
        }
    }

    var body: some View {
        TabView(selection: $activeTab) {
            // MARK: - Tab 1: Workout Selection
            NavigationView {
                workoutTabContent
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
        .onReceive(connectivityManager.$activeWorkout) { activeWorkout in
            if activeWorkout != nil && !(activeWorkout?.postponed ?? false) {
                activeTab = 0
            }
        }
        .onReceive(workoutManager.$workoutSessionState) { state in
            if state == .running || state == .paused {
                activeTab = 0
            }
        }
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
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    @State private var showRemoveSheet = false
    
    // Quick add presets: Copo 200ml, Garrafa 500ml, Shakeira 750ml
    let presets = [200, 500, 750]
    
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
                                colors: progress >= 1.0 ? [.green, .cyan] : [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.spring(), value: connectivityManager.waterIntakeCurrent)
                    
                    VStack(spacing: 1) {
                        Image(systemName: progress >= 1.0 ? "checkmark.seal.fill" : "drop.fill")
                            .font(.system(size: 16))
                            .foregroundColor(progress >= 1.0 ? .green : .blue)
                        
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
                                if Double(newTotal) >= Double(connectivityManager.waterIntakeTarget) {
                                    WatchHapticManager.shared.playWaterIntake()
                                } else {
                                    WatchHapticManager.shared.play(.light)
                                }
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
                    
                    // Quick -250ml undo + custom remove button
                    if connectivityManager.waterIntakeCurrent > 0 {
                        HStack(spacing: 6) {
                            Button(action: {
                                #if canImport(WatchKit)
                                WatchHapticManager.shared.play(.light)
                                #endif
                                let newTotal = max(0, connectivityManager.waterIntakeCurrent - 250)
                                connectivityManager.updateWaterIntake(newAmountMl: newTotal)
                            }) {
                                Text("-250 ml")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                showRemoveSheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 9))
                                    Text("Outro")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.10))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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

struct RoutineSelectionRow: View {
    let routine: WatchRoutine
    let isCompleted: Bool
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        NavigationLink(destination: WorkoutSetupView(routine: routine)) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: isCompleted ? "checkmark.seal.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
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
                
                // Favorite button
                Button(action: {
                    onFavoriteToggle()
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
                .buttonStyle(PlainButtonStyle())
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

