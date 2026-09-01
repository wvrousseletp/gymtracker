import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct WatchExerciseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let existingNote: String
    let onSave: (String) -> Void
    
    @State private var noteText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NOTA DO EXERCÍCIO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                        Text(exerciseName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                TextField("Fale ou digite sua nota...", text: $noteText)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                
                // Quick preset tags
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        quickTagButton("Subir carga")
                        quickTagButton("Leve")
                        quickTagButton("Pesado")
                    }
                    HStack(spacing: 4) {
                        quickTagButton("Dor leve")
                        quickTagButton("Execução boa")
                    }
                }
                .padding(.top, 2)
                
                HStack(spacing: 6) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancelar")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        onSave(noteText)
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.success)
                        #endif
                        dismiss()
                    }) {
                        Text("Salvar")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .navigationTitle("Nota")
        .onAppear {
            noteText = existingNote
        }
    }
    
    private func quickTagButton(_ tag: String) -> some View {
        Button(action: {
            if noteText.isEmpty {
                noteText = tag
            } else {
                noteText += ", \(tag)"
            }
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.click)
            #endif
        }) {
            Text(tag)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
