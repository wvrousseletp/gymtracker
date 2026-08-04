import Foundation
import os.log
#if os(watchOS)
import WatchKit
#endif

class WatchBatterySaverManager: ObservableObject {
    static let shared = WatchBatterySaverManager()
    
    @Published var isBatterySaverEnabled = false
    @Published var batteryLevel: Double = 1.0
    @Published var batteryState: WKInterfaceDeviceBatteryState = .charging
    
    private var batteryCheckTimer: Timer?
    private let batteryCheckInterval: TimeInterval = 60 // Check every minute
    
    // Thresholds
    private let lowBatteryThreshold: Double = 0.20 // 20%
    private let criticalBatteryThreshold: Double = 0.10 // 10%
    
    // Settings
    private var reducedRefreshRate = true
    private var reducedSensorSampling = true
    private var reducedHapticFeedback = true
    
    private init() {
        #if os(watchOS)
        startBatteryMonitoring()
        #endif
    }
    
    // MARK: - Battery Monitoring
    
    private func startBatteryMonitoring() {
        #if os(watchOS)
        updateBatteryInfo()
        
        batteryCheckTimer = Timer.scheduledTimer(withTimeInterval: batteryCheckInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
            self?.checkBatteryThresholds()
        }
        #endif
    }
    
    private func updateBatteryInfo() {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        batteryLevel = Double(device.batteryLevel)
        batteryState = device.batteryState
        
        os_log("Battery level: %.2f, state: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Battery"), type: .info, batteryLevel, batteryState.rawValue)
        #endif
    }
    
    private func checkBatteryThresholds() {
        #if os(watchOS)
        // Auto-enable battery saver when battery is low
        if batteryLevel <= lowBatteryThreshold && !isBatterySaverEnabled {
            enableBatterySaver(auto: true)
        }
        
        // Auto-disable battery saver when battery is charged
        if batteryLevel > 0.30 && isBatterySaverEnabled {
            disableBatterySaver(auto: true)
        }
        
        // Increase HealthKit sync interval for critical battery
        if batteryLevel <= criticalBatteryThreshold {
            WorkoutManager.shared.setCriticalBatterySampling(enabled: true)
            // Play haptic warning when battery becomes critical
            WatchHapticManager.shared.playBatteryCritical()
        } else if batteryLevel > 0.15 {
            WorkoutManager.shared.setCriticalBatterySampling(enabled: false)
        }
        #endif
    }
    
    // MARK: - Battery Saver Control
    
    func enableBatterySaver(auto: Bool = false) {
        guard !isBatterySaverEnabled else { return }
        
        isBatterySaverEnabled = true
        
        #if os(watchOS)
        // Reduce refresh rate
        if reducedRefreshRate {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        }
        
        // Reduce sensor sampling in WorkoutManager
        if reducedSensorSampling {
            WorkoutManager.shared.setReducedSensorSampling(enabled: true)
        }
        
        // Reduce haptic feedback
        if reducedHapticFeedback {
            WatchHapticManager.shared.setHapticsEnabled(false)
        }
        #endif
        
        os_log("Battery saver enabled (auto: %d)", log: OSLog(subsystem: "com.losmooscles.watch", category: "Battery"), type: .info, auto ? 1 : 0)
    }
    
    func disableBatterySaver(auto: Bool = false) {
        guard isBatterySaverEnabled else { return }
        
        isBatterySaverEnabled = false
        
        #if os(watchOS)
        // Restore refresh rate
        if reducedRefreshRate {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = false
        }
        
        // Restore sensor sampling in WorkoutManager
        if reducedSensorSampling {
            WorkoutManager.shared.setReducedSensorSampling(enabled: false)
        }
        
        // Restore haptic feedback
        if reducedHapticFeedback {
            WatchHapticManager.shared.setHapticsEnabled(true)
        }
        #endif
        
        os_log("Battery saver disabled (auto: %d)", log: OSLog(subsystem: "com.losmooscles.watch", category: "Battery"), type: .info, auto ? 1 : 0)
    }
    
    func toggleBatterySaver() {
        if isBatterySaverEnabled {
            disableBatterySaver()
        } else {
            enableBatterySaver()
        }
    }
    
    // MARK: - Battery Saver Settings
    
    func setReducedRefreshRate(_ enabled: Bool) {
        reducedRefreshRate = enabled
        if isBatterySaverEnabled {
            // Apply setting immediately if battery saver is active
            #if os(watchOS)
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = enabled
            #endif
        }
    }
    
    func setReducedSensorSampling(_ enabled: Bool) {
        reducedSensorSampling = enabled
        if isBatterySaverEnabled {
            WorkoutManager.shared.setReducedSensorSampling(enabled: enabled)
        }
    }
    
    func setReducedHapticFeedback(_ enabled: Bool) {
        reducedHapticFeedback = enabled
        if isBatterySaverEnabled {
            WatchHapticManager.shared.setHapticsEnabled(!enabled)
        }
    }
    
    // MARK: - Battery Status
    
    var isLowBattery: Bool {
        return batteryLevel <= lowBatteryThreshold
    }
    
    var isCriticalBattery: Bool {
        return batteryLevel <= criticalBatteryThreshold
    }
    
    var batteryPercentage: Int {
        return Int(batteryLevel * 100)
    }
    
    var estimatedTimeRemaining: String? {
        #if os(watchOS)
        // This is an approximation - actual time remaining depends on usage
        if batteryState == .charging {
            return "Carregando"
        }
        
        let baseMinutes: Double = 180 // 3 hours at 100%
        let remainingMinutes = baseMinutes * batteryLevel
        
        if remainingMinutes >= 60 {
            return "\(Int(remainingMinutes / 60))h \(Int(remainingMinutes.truncatingRemainder(dividingBy: 60)))min"
        } else {
            return "\(Int(remainingMinutes))min"
        }
        #else
        return nil
        #endif
    }
    
    // MARK: - Power Saving Tips
    
    func getPowerSavingTips() -> [String] {
        var tips: [String] = []
        
        if isLowBattery {
            tips.append("Ative o modo de economia de bateria")
        }
        
        if batteryState == .charging {
            tips.append("Carregue o Apple Watch")
        }
        
        if WorkoutManager.shared.workoutSessionState == .running {
            tips.append("Termine o treino atual")
        }
        
        tips.append("Reduza o brilho da tela")
        tips.append("Desative notificações não essenciais")
        tips.append("Use o modo de cinema em treinos longos")
        
        return tips
    }
    
    // MARK: - Cleanup
    
    deinit {
        batteryCheckTimer?.invalidate()
    }
}

// MARK: - WorkoutManager Extension for Reduced Sampling

extension WorkoutManager {
    private var reducedSamplingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "reduced_sampling_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "reduced_sampling_enabled")
        }
    }
    
    private var criticalBatterySamplingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "critical_battery_sampling_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "critical_battery_sampling_enabled")
        }
    }
    
    func setReducedSensorSampling(enabled: Bool) {
        reducedSamplingEnabled = enabled
        
        // Adjust health sync interval based on sampling mode
        if enabled {
            healthSyncInterval = 10 // Sync every 10 seconds instead of 5
        } else {
            healthSyncInterval = 5
        }
        
        os_log("Reduced sensor sampling: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info, enabled ? 1 : 0)
    }
    
    func setCriticalBatterySampling(enabled: Bool) {
        criticalBatterySamplingEnabled = enabled
        
        // Further increase health sync interval for critical battery
        if enabled {
            healthSyncInterval = 20 // Sync every 20 seconds for critical battery
        } else if reducedSamplingEnabled {
            healthSyncInterval = 10 // Restore to reduced sampling if still enabled
        } else {
            healthSyncInterval = 5 // Restore to normal sampling
        }
        
        os_log("Critical battery sampling: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "HealthKit"), type: .info, enabled ? 1 : 0)
    }
}
