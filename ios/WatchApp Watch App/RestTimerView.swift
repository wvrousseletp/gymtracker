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
            // Fundo escuro premium (Black)
            Color.black.ignoresSafeArea()

            // Efeito de brilho radial sutil
            if !isLuminanceReduced {
                RadialGradient(
                    colors: [themeColor.opacity(0.15), Color.black],
                    center: .center,
                    startRadius: 20,
                    endRadius: WKInterfaceDevice.current().screenBounds.width / 1.2
                )
                .ignoresSafeArea()
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseScale = 1.05
                        pulseOpacity = 0.8
                    }
                }
            }
            
            // Anel de progresso que ocupa quase a tela toda (estilo iOS)
            if !isLuminanceReduced {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 4)
                    .padding(4)
                
                Circle()
                    .trim(from: 0.0, to: restTimer.totalSeconds > 0 ? CGFloat(timeRemaining) / CGFloat(restTimer.totalSeconds) : 0)
                    .stroke(
                        themeColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .padding(4)
                    .shadow(color: themeColor.opacity(0.5), radius: 6)
                    .animation(.linear(duration: 0.5), value: timeRemaining)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 8)
                
                // Título: PREPARE-SE ou DESCANSO
                Text(restTimer.isPrep ? "PREPARE-SE" : "DESCANSO")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(themeColor)
                    .tracking(1.0)
                    .padding(.bottom, -2)

                // Contagem regressiva GIGANTE (premium)
                Text("\(timeRemaining)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(isLuminanceReduced ? .gray : .white)
                    .tracking(-2.0) // Aproximar os números (estilo iOS)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)

                // Próximo Exercício (Glass style sutil)
                VStack(spacing: 2) {
                    Text(restTimer.nextExerciseName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("Série \(restTimer.nextSetNum)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .padding(.bottom, 8)
                
                Spacer(minLength: 4)

                // Botão de Pular grande e chamativo
                Button(action: {
                    connectivityManager.skipRest()
                }) {
                    Text(restTimer.isPrep ? "Iniciar Agora" : "Pular")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(isLuminanceReduced ? Color.gray : Color.white)
                        .cornerRadius(19)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
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
