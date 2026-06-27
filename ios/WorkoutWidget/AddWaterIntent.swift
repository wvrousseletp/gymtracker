import AppIntents
import WidgetKit
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Adicionar Água"
    
    @Parameter(title: "Quantidade")
    var amount: Int
    
    init() {}
    
    init(amount: Int) {
        self.amount = amount
    }
    
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vicente.losmooscles")
        let current = sharedDefaults?.integer(forKey: "waterIntakeCurrent") ?? 0
        sharedDefaults?.set(current + amount, forKey: "waterIntakeCurrent")
        
        // Reload the widget timelines to reflect changes immediately
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterIntakeWidget")
        
        return .result()
    }
}
