import SwiftUI

struct FinishWorkoutSheet: View {
    @Binding var isPresented: Bool
    @State private var rpe: Double = 7
    @State private var notes: String = ""
    let onConfirm: (Int, String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Finalizar Treino")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)

                Text("Como foi o esforço?")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                VStack(spacing: 4) {
                    Text("RPE \(Int(rpe))")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(.orange)
                }
                .padding(.horizontal, 4)

                Button(action: {
                    let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    onConfirm(Int(rpe), finalNotes.isEmpty ? "Treino concluído via Apple Watch" : finalNotes)
                    isPresented = false
                }) {
                    Text("Confirmar")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button("Cancelar") {
                    isPresented = false
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
            }
            .padding(8)
        }
    }
}
