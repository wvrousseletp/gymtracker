import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct WatchPlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    let targetWeight: Double
    
    @State private var barWeight: Double = 20.0 // Default Olympic bar 20kg
    
    // Standard available plates (in kg)
    let availablePlates: [Double] = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
    
    // Calculates plates needed per side
    private var platesPerSide: [(weight: Double, count: Int)] {
        let weightForPlates = max(0, targetWeight - barWeight)
        var weightPerSide = weightForPlates / 2.0
        
        var result: [(weight: Double, count: Int)] = []
        
        for plate in availablePlates {
            if weightPerSide >= plate {
                let count = Int(weightPerSide / plate)
                if count > 0 {
                    result.append((weight: plate, count: count))
                    weightPerSide -= Double(count) * plate
                }
            }
        }
        return result
    }
    
    private func plateColor(for weight: Double) -> Color {
        switch weight {
        case 25.0: return .red
        case 20.0: return .blue
        case 15.0: return .yellow
        case 10.0: return .green
        case 5.0: return .white
        case 2.5: return .orange
        case 1.25: return .purple
        default: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CALCULADORA DE ANILHAS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f kg Total", targetWeight))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Bar selector
                HStack(spacing: 4) {
                    Button(action: {
                        barWeight = 20.0
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }) {
                        Text("20kg")
                            .font(.system(size: 9, weight: barWeight == 20.0 ? .bold : .regular))
                            .foregroundColor(barWeight == 20.0 ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(barWeight == 20.0 ? Color.orange.opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        barWeight = 10.0
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }) {
                        Text("10kg")
                            .font(.system(size: 9, weight: barWeight == 10.0 ? .bold : .regular))
                            .foregroundColor(barWeight == 10.0 ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(barWeight == 10.0 ? Color.orange.opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        barWeight = 0.0
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }) {
                        Text("Sem Barra")
                            .font(.system(size: 9, weight: barWeight == 0.0 ? .bold : .regular))
                            .foregroundColor(barWeight == 0.0 ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(barWeight == 0.0 ? Color.orange.opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Plates Breakdown
                VStack(alignment: .leading, spacing: 4) {
                    Text("POR LADO DA BARRA:")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if platesPerSide.isEmpty {
                        Text(targetWeight <= barWeight ? "Apenas o peso da barra" : "Carga muito leve para anilhas")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(platesPerSide, id: \.weight) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(plateColor(for: item.weight))
                                    .frame(width: 10, height: 10)
                                
                                Text("\(item.count)x")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(String(format: "%.2f kg", item.weight))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(String(format: "= %.1f kg", item.weight * Double(item.count)))
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }
                }
                
                // Dismiss Button
                Button(action: {
                    dismiss()
                }) {
                    Text("Fechar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .navigationTitle("Anilhas")
    }
}
