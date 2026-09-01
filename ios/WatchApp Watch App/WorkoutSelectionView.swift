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
        .accessibilityLabel(isCompleted ? "\(item.title), treino concluído" : "\(item.title), \(item.subtitle)")
        .accessibilityHint(isCompleted ? "Toque para ver detalhes" : "Toque para iniciar treino")
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
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    @StateObject var workoutManager = WorkoutManager.shared
    @State private var activeTab = 0
    @State private var searchText = ""
    @State private var selectedMuscleFilter: String? = nil
    @State private var showFavoritesOnly = false

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
    
    private var favoriteRoutines: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "favorite_routines") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "favorite_routines")
        }
    }
    
    private var muscleGroups: [String] {
        // WatchRoutineExercise only has exerciseId, sets, reps, rest, weight
        // Muscle info not available on watch model
        return []
    }
    
    private var filteredRoutines: [WatchRoutine] {
        var routines = connectivityManager.routines
        
        // Filter by search text
        if !searchText.isEmpty {
            routines = routines.filter { routine in
                routine.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Muscle filter not available (WatchRoutineExercise lacks muscle field)
        let _ = selectedMuscleFilter
        
        // Filter by favorites
        if showFavoritesOnly {
            routines = routines.filter { favoriteRoutines.contains($0.id) }
        }
        
        return routines
    }
    
    private var filteredExercises: [WatchLibraryExercise] {
        var exercises = filteredLibrary
        
        // Filter by search text
        if !searchText.isEmpty {
            exercises = exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by muscle group
        if let muscle = selectedMuscleFilter {
            exercises = exercises.filter { $0.muscle == muscle }
        }
        
        return exercises
    }
    
    private func toggleFavorite(routineId: String) {
        var favorites = favoriteRoutines
        if favorites.contains(routineId) {
            favorites.remove(routineId)
        } else {
            favorites.insert(routineId)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "favorite_routines")
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
    private var searchAndFilterBar: some View {
        VStack(spacing: 4) {
            // Filter buttons
            HStack(spacing: 4) {
                // Favorites toggle
                Button(action: {
                    showFavoritesOnly.toggle()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                            .font(.system(size: 8))
                        Text("Favoritos")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(showFavoritesOnly ? .yellow : .gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(showFavoritesOnly ? Color.yellow.opacity(0.15) : Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Muscle filter
                if !muscleGroups.isEmpty {
                    Button {
                        Button("Todos") {
                            selectedMuscleFilter = nil
                        }
                        ForEach(muscleGroups, id: \.self) { muscle in
                            Button(muscle) {
                                selectedMuscleFilter = muscle
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 8))
                            Text(selectedMuscleFilter ?? "Músculos")
                                .font(.system(size: 8, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(selectedMuscleFilter != nil ? .blue : .gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(selectedMuscleFilter != nil ? Color.blue.opacity(0.15) : Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var offlineWarningSection: some View {
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
    }

    @ViewBuilder
    private var routinesSection: some View {
        if !filteredRoutines.isEmpty {
            Section(header: 
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .bold))
                    Text("TODOS OS TREINOS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
            ) {
                ForEach(filteredRoutines) { routine in
                    let isCompleted = connectivityManager.streak.completedTodayRoutines.contains(routine.name)
                    let isFavorite = favoriteRoutines.contains(routine.id)
                    
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
        } else if !connectivityManager.routines.isEmpty {
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
    private var singleExercisesSection: some View {
        if !filteredExercises.isEmpty {
            Section(header: 
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("EXERCÍCIOS AVULSOS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(.blue)
            ) {
                ForEach(filteredExercises) { exercise in
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
        } else if !filteredLibrary.isEmpty {
            Section {
                HStack {
                    Spacer()
                    Text("Nenhum exercício encontrado")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var quickStartSection: some View {
        Section {
            Button(action: {
                if let first = connectivityManager.library.first {
                    connectivityManager.startSingleExercise(exerciseId: first.id)
                    #if canImport(WatchKit)
                    WKInterfaceDevice.current().play(.start)
                    #endif
                }
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 26, height: 26)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Treino Livre")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Iniciar sessão avulsa")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var workoutContentList: some View {
        VStack(spacing: 0) {
            searchAndFilterBar
            
            List {
                offlineWarningSection
                quickStartSection
                if let activeWorkout = connectivityManager.activeWorkout {
                    postponedWorkoutSection(activeWorkout: activeWorkout)
                }
                todayPlannedSection
                routinesSection
                singleExercisesSection
            }
            .listStyle(.carousel)
        }
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
                                    WKInterfaceDevice.current().play(.success)
                                } else {
                                    WKInterfaceDevice.current().play(.click)
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

