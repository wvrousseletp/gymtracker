import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct RestTimerView: View {
    let restTimer: WatchRestTimer
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    @State private var timeRemaining: Int = 0
    @State private var didAutoSkip = false
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    private var themeColor: Color {
        restTimer.isPrep ? Color.yellow : Color.orange
    }

    var body: some View {
        ZStack {
            // Ambient pulsing radial gradient background
            if !isLuminanceReduced {
                RadialGradient(
                    colors: [themeColor.opacity(0.18), Color.black],
                    center: .center,
                    startRadius: 5,
                    endRadius: 90
                )
                .ignoresSafeArea()
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                        pulseOpacity = 0.75
                    }
                }
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 4) {
                // Badge superior indicando o estado
                Text(restTimer.isPrep ? "PREPARE-SE" : "DESCANSO ATIVO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(themeColor.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeColor.opacity(0.35), lineWidth: 1)
                    )

                // Texto informativo do próximo exercício
                VStack(spacing: 2) {
                    Text(restTimer.isPrep ? "ENTRANDO EM:" : "PRÓXIMO EXERCÍCIO:")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Text("\(restTimer.nextExerciseName)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Série \(restTimer.nextSetNum)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .padding(.horizontal, 6)
                .multilineTextAlignment(.center)

                // Cronômetro Circular Moderno com Efeito Glow
                ZStack {
                    if !isLuminanceReduced {
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
                    } else {
                        Circle()
                            .stroke(themeColor.opacity(0.3), lineWidth: 1.5)
                    }

                    VStack(spacing: -3) {
                        Text("\(timeRemaining)")
                            .font(.system(size: 18, weight: isLuminanceReduced ? .bold : .black, design: .rounded))
                            .foregroundColor(isLuminanceReduced ? .gray : .white)
                        Text("seg")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 48, height: 48)

                // Botão Pular de Visual Moderno (Pill Glass)
                Button(action: {
                    connectivityManager.skipRest()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 8))
                        Text(restTimer.isPrep ? "Pular" : "Pular")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(themeColor)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .ignoresSafeArea(.keyboard)
            .padding(.bottom, 2)
        }
        .onAppear {
            didAutoSkip = false
            updateTimeRemaining()
        }
        .onChange(of: restTimer.endTime) { _ in
            didAutoSkip = false
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            if !isLuminanceReduced {
                updateTimeRemaining()
            }
        }
        .onChange(of: isLuminanceReduced) { reduced in
            if !reduced {
                updateTimeRemaining()
            }
        }
    }

    private func updateTimeRemaining() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let diff = restTimer.endTime - now
        let remaining = max(0, Int(round(Double(diff) / 1000.0)))
        
        if remaining != timeRemaining {
            timeRemaining = remaining
            if remaining == 0 && !didAutoSkip {
                didAutoSkip = true
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.success)
                WKInterfaceDevice.current().play(.click)
                #endif
                connectivityManager.skipRest()
            }
        }
    }
}
