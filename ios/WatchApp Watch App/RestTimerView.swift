import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct RestTimerView: View {
    let restTimer: WatchRestTimer
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var timeRemaining: Int = 0
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var themeColor: Color {
        restTimer.isPrep ? Color.yellow : Color.orange
    }

    var body: some View {
        VStack(spacing: 3) {
            // Badge superior indicando o estado
            Text(restTimer.isPrep ? "PREPARO" : "DESCANSO")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(themeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(themeColor.opacity(0.15))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1)
                )

            // Texto informativo do próximo exercício
            VStack(spacing: 0) {
                Text(restTimer.isPrep ? "Prepare-se para:" : "Próximo:")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("\(restTimer.nextExerciseName)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Série \(restTimer.nextSetNum)")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 6)
            .multilineTextAlignment(.center)

            // Cronômetro Circular Moderno com Efeito Glow
            ZStack {
                Circle()
                    .stroke(lineWidth: 2.5)
                    .opacity(0.08)
                    .foregroundColor(.white)

                Circle()
                    .trim(from: 0.0, to: restTimer.totalSeconds > 0 ? CGFloat(timeRemaining) / CGFloat(restTimer.totalSeconds) : 0)
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundColor(themeColor)
                    .rotationEffect(Angle(degrees: 270.0))
                    .shadow(color: themeColor.opacity(0.6), radius: 3)

                VStack(spacing: -3) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("seg")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 56, height: 56)

            // Botão Pular de Visual Moderno (Pill Glass)
            Button(action: {
                connectivityManager.skipRest()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 8))
                    Text(restTimer.isPrep ? "Pular Preparo" : "Pular Descanso")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(themeColor)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
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
