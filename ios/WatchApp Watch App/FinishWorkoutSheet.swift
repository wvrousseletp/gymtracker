import SwiftUI

struct FinishWorkoutSheet: View {
    @Binding var isPresented: Bool
    var workoutName: String = ""
    var durationText: String = ""
    var completedSets: Int = 0
    var totalSets: Int = 0
    @State private var rpe: Double = 7
    @State private var notes: String = ""
    let onConfirm: (Int, String) -> Void
    var onDiscard: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(completedSets == 0 && totalSets > 0 ? "Nenhuma série feita" : "Finalizar Treino")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if !workoutName.isEmpty {
                    Text(workoutName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }

                if totalSets > 0 {
                    HStack(spacing: 8) {
                        if !durationText.isEmpty {
                            VStack(spacing: 1) {
                                Text("Tempo")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                                Text(durationText)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        }

                        VStack(spacing: 1) {
                            Text("Séries")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            Text("\(completedSets)/\(totalSets)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(completedSets == 0 ? .red : .green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }
                }

                if completedSets == 0 && totalSets > 0 {
                    Text("Você ainda não marcou nenhuma série. Deseja continuar ou descartar?")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Continuar Treino")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if let onDiscard = onDiscard {
                        Button(action: {
                            isPresented = false
                            onDiscard()
                        }) {
                            Text("Descartar")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.14))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    if totalSets > completedSets {
                        Text("Restam \(totalSets - completedSets) série(s) em aberto")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.yellow)
                    }

                    VStack(spacing: 4) {
                        Text("Esforço • RPE \(Int(rpe))")
                            .font(.system(size: 13, weight: .black, design: .rounded))
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
                        Text("Concluir Treino")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button("Voltar") {
                        isPresented = false
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                }
            }
            .padding(8)
        }
    }
}
