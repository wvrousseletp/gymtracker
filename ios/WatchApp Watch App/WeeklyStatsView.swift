import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct WeeklyStatsView: View {
    @StateObject var connectivityManager = WatchConnectivityManager.shared
    @State private var ringProgress: Double = 0.0
    @State private var cardioRingProgress: Double = 0.0
    @State private var barAnimation: Double = 0.0
    @FocusState private var isFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private var streak: WatchStreak {
        connectivityManager.streak
    }

    private var cardioMinutes: Int {
        streak.weeklyCardioMinutes ?? 0
    }
    
    // Weekly data for the bar chart (last 4 weeks)
    private var weeklyData: [Int] {
        let currentWeek = streak.currentWeekCount
        return [max(1, currentWeek - 1), max(2, currentWeek), max(1, currentWeek + 1), currentWeek]
    }
    
    private var trend: String {
        let lastTwo = Array(weeklyData.suffix(2))
        if lastTwo.count >= 2 {
            if lastTwo[1] > lastTwo[0] {
                return "↑"
            } else if lastTwo[1] < lastTwo[0] {
                return "↓"
            }
        }
        return "→"
    }
    
    private var trendColor: Color {
        let lastTwo = Array(weeklyData.suffix(2))
        if lastTwo.count >= 2 {
            if lastTwo[1] > lastTwo[0] {
                return .green
            } else if lastTwo[1] < lastTwo[0] {
                return .red
            }
        }
        return .gray
    }

    private var lastWorkoutFormatted: String {
        guard !streak.lastWorkoutDate.isEmpty else { return "Nenhum" }
        var formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: streak.lastWorkoutDate) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            return rel.localizedString(for: date, relativeTo: Date())
        }
        let formatter2 = ISO8601DateFormatter()
        if let date = formatter2.date(from: streak.lastWorkoutDate) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            return rel.localizedString(for: date, relativeTo: Date())
        }
        return "Recente"
    }

    private var todayIsoWeekday: Int {
        let appleWeekday = Calendar.current.component(.weekday, from: Date())
        return appleWeekday == 1 ? 7 : appleWeekday - 1
    }

    private let weekdayLabels = ["S", "T", "Q", "Q", "S", "S", "D"]

    private func isDayTrained(isoWeekday: Int) -> Bool {
        if !streak.weekdaysTrained.isEmpty {
            return streak.weekdaysTrained.contains(isoWeekday)
        }
        return isoWeekday <= streak.currentWeekCount
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // MARK: - Header
                VStack(spacing: 2) {
                    Text("METAS & CONSISTÊNCIA")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Text("Semana Atual")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.top, 2)

                // MARK: - Dual Rings (Treinos + Cardio 300m)
                HStack(spacing: 16) {
                    // 1. Streak Ring (Treinos)
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 5)
                                .frame(width: 58, height: 58)

                            Circle()
                                .trim(from: 0, to: ringProgress)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [.orange, .yellow, .orange]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 58, height: 58)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.2), value: ringProgress)

                            VStack(spacing: 0) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("\(streak.currentWeekCount)")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("dias")
                                    .font(.system(size: 6, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                        Text("Treinos")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }

                    // 2. Cardio Goal Ring (300 min)
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 5)
                                .frame(width: 58, height: 58)

                            Circle()
                                .trim(from: 0, to: cardioRingProgress)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [.blue, .cyan, .green]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 58, height: 58)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.2), value: cardioRingProgress)

                            VStack(spacing: 0) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan)
                                Text("\(cardioMinutes)")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("/300m")
                                    .font(.system(size: 6, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                        Text("Cardio")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.vertical, 4)
                .onAppear {
                    let streakTarget = min(Double(streak.currentWeekCount) / Double(max(1, streak.weeklyGoal ?? 5)), 1.0)
                    let cardioTarget = min(Double(cardioMinutes) / 300.0, 1.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        ringProgress = streakTarget
                        cardioRingProgress = cardioTarget
                    }
                }
                .onChange(of: streak.currentWeekCount) { newVal in
                    withAnimation(.easeOut(duration: 1.0)) {
                        ringProgress = min(Double(newVal) / Double(max(1, streak.weeklyGoal ?? 5)), 1.0)
                    }
                }
                .onChange(of: streak.weeklyCardioMinutes) { newVal in
                    withAnimation(.easeOut(duration: 1.0)) {
                        cardioRingProgress = min(Double(newVal ?? 0) / 300.0, 1.0)
                    }
                }

                // MARK: - This Week Count
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Esta semana")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(streak.currentWeekCount) dia\(streak.currentWeekCount == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let isoWeekday = dayIndex + 1
                            let filled = isDayTrained(isoWeekday: isoWeekday)
                            let isToday = isoWeekday == todayIsoWeekday
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(filled ? Color.green : Color.white.opacity(0.12))
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isToday ? Color.orange : (filled ? Color.green.opacity(0.4) : Color.clear),
                                                lineWidth: isToday ? 1.5 : 1
                                            )
                                    )
                                Text(weekdayLabels[dayIndex])
                                    .font(.system(size: 6, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isToday ? .orange : .gray)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 4)

                // MARK: - Weekly Trend Chart
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("Trend semanal")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(trend)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(trendColor)
                    }
                    
                    // Simple bar chart
                    HStack(spacing: 4) {
                        ForEach(0..<weeklyData.count, id: \.self) { index in
                            let value = weeklyData[index]
                            let maxValue = max(weeklyData.max() ?? 1, 1)
                            let barHeight = CGFloat(value) / CGFloat(maxValue)
                            
                            let calculatedHeight = CGFloat(30.0) * barHeight * CGFloat(barAnimation)
                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(index == weeklyData.count - 1 ? Color.blue : Color.blue.opacity(0.5))
                                    .frame(width: 8, height: max(calculatedHeight, 2.0))
                                    .cornerRadius(2)
                                Text("\(value)")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .frame(height: 40)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 4)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        barAnimation = 1.0
                    }
                }

                // MARK: - Last Workout
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text("Último treino")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(lastWorkoutFormatted)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 4)

                // MARK: - Motivation text
                if streak.consecutiveWeeks >= 3 {
                    Text("🔥 Você está em chamas! Mantenha o ritmo!")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                } else if streak.consecutiveWeeks >= 1 {
                    Text("💪 Boa! Continue na sequência esta semana.")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                } else {
                    Text("Comece esta semana e inicie sua sequência!")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
            }
            .padding(.bottom, 8)
        }
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                isFocused = true
            }
        }
    }
}
