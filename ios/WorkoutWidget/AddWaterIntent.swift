import AppIntents
import WidgetKit
import Foundation

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        let savedDate = sharedDefaults?.string(forKey: "waterIntakeDate") ?? ""
        let baseWater = (savedDate == todayStr)
            ? (sharedDefaults?.integer(forKey: "waterIntakeCurrent") ?? 0)
            : 0
        let updatedWater = max(0, baseWater + amount)

        sharedDefaults?.set(updatedWater, forKey: "waterIntakeCurrent")
        sharedDefaults?.set(updatedWater, forKey: "cached_water_intake")
        sharedDefaults?.set(todayStr, forKey: "waterIntakeDate")
        sharedDefaults?.synchronize()

        // Reload the widget timelines to reflect changes immediately
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterIntakeWidget")

        return .result()
    }
}
