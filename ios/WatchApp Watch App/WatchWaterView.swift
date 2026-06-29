import SwiftUI

struct WatchWaterView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
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
                            let newTotal = max(0, connectivityManager.waterIntakeCurrent - 150)
                            connectivityManager.updateWaterIntake(newAmountMl: newTotal)
                            #if os(watchOS)
                            WKInterfaceDevice.current().play(.directionDown)
                            #endif
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 9))
                                Text("Remover 150ml")
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
    }
}

struct WatchWaterView_Previews: PreviewProvider {
    static var previews: some View {
        WatchWaterView()
    }
}
