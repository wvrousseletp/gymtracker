import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct RestTimerView: View {
    let restTimer: WatchRestTimer
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var timeRemaining: Int = 0
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            Text(restTimer.isPrep ? "PREPARO" : "DESCANSO")
                .font(.headline)
                .foregroundColor(restTimer.isPrep ? .yellow : .orange)

            Text(restTimer.isPrep ? "Prepare-se para:" : "Próximo:")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            Text("\(restTimer.nextExerciseName) (S\(restTimer.nextSetNum))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)

            ZStack {
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.3)
                    .foregroundColor(restTimer.isPrep ? Color.yellow : Color.orange)

                Circle()
                    .trim(from: 0.0, to: restTimer.totalSeconds > 0 ? CGFloat(timeRemaining) / CGFloat(restTimer.totalSeconds) : 0)
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .foregroundColor(restTimer.isPrep ? Color.yellow : Color.orange)
                    .rotationEffect(Angle(degrees: 270.0))

                Text("\(timeRemaining)s")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 80)
            .padding(.vertical, 4)

            Button(action: {
                connectivityManager.skipRest()
            }) {
                Text(restTimer.isPrep ? "Pular Preparo" : "Pular Descanso")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(restTimer.isPrep ? .yellow : .orange)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let diff = restTimer.endTime - now
        let remaining = max(0, Int(round(Double(diff) / 1000.0)))
        
        if remaining != timeRemaining {
            timeRemaining = remaining
            if remaining == 0 {
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.success)
                WKInterfaceDevice.current().play(.click)
                #endif
            }
        }
    }
}
