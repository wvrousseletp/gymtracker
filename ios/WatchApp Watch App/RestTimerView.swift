import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct RestTimerView: View {
    let durationSeconds: Int
    @Binding var isPresented: Bool
    @State private var timeRemaining: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Text("Descanso")
                .font(.headline)
                .foregroundColor(.gray)

            ZStack {
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.3)
                    .foregroundColor(Color.orange)

                Circle()
                    .trim(from: 0.0, to: CGFloat(timeRemaining) / CGFloat(durationSeconds))
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.orange)
                    .rotationEffect(Angle(degrees: 270.0))

                Text("\(timeRemaining)s")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 90, height: 90)
            .padding()

            Button(action: {
                isPresented = false
            }) {
                Text("Pular")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            timeRemaining = durationSeconds
        }
        .onReceive(timer) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                // Timer completo: vibra o Apple Watch
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.success)
                WKInterfaceDevice.current().play(.click)
                #endif
                isPresented = false
            }
        }
    }
}
