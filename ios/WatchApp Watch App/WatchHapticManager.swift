import Foundation
import os.log
import UserNotifications
#if os(watchOS)
import WatchKit
#endif

class WatchHapticManager {
    static let shared = WatchHapticManager()

    private let enabledKey = "watch_haptics_enabled"
    private let intensityKey = "watch_haptics_intensity"
    private let restNotifId = "watch_rest_timer_end"
    private var lastScheduledRestEndTimeMs: Int64 = 0
    private var batterySaverLowIntensity: Bool = false

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            hapticsEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        if let raw = UserDefaults.standard.string(forKey: intensityKey),
           let saved = HapticIntensity(rawValue: raw) {
            currentIntensity = saved
        }
    }
    
    // MARK: - Haptic Patterns
    
    enum HapticPattern {
        case success           // Series completed successfully
        case failure           // Failure registered
        case reminder          // Rest timer finished
        case celebration       // PR beaten
        case warning           // Warning/attention
        case light             // Subtle feedback
        case medium            // Standard feedback
        case heavy             // Strong feedback
    }

    enum HapticIntensity: String {
        case low
        case medium
        case high

        var label: String {
            switch self {
            case .low: return "Leve"
            case .medium: return "Normal"
            case .high: return "Forte"
            }
        }
    }
    
    // MARK: - Public Methods
    
    private var lastPlayedTime: Date = Date.distantPast
    
    func play(_ pattern: HapticPattern, bypassThrottle: Bool = false) {
        guard hapticsEnabled else { return }
        #if os(watchOS)
        let now = Date()
        if !bypassThrottle {
            guard now.timeIntervalSince(lastPlayedTime) > 0.1 else { return }
        }
        lastPlayedTime = now

        let effective = resolvePatternForIntensity(pattern)
        let device = WKInterfaceDevice.current()
        
        switch effective {
        case .success:
            device.play(.success)
            
        case .failure:
            device.play(.failure)
            
        case .reminder:
            device.play(.notification)
            
        case .celebration:
            device.play(.directionUp)
            
        case .warning:
            device.play(.retry)
            
        case .light:
            device.play(.click)
            
        case .medium:
            device.play(.start)
            
        case .heavy:
            device.play(.stop)
        }
        
        os_log("Played haptic pattern: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, effective.hashValue)
        #endif
    }

    private func resolvePatternForIntensity(_ pattern: HapticPattern) -> HapticPattern {
        let effectiveIntensity: HapticIntensity = batterySaverLowIntensity ? .low : currentIntensity
        switch effectiveIntensity {
        case .low:
            switch pattern {
            case .success, .medium: return .light
            case .celebration, .heavy: return .medium
            case .failure, .warning: return .light
            default: return pattern
            }
        case .medium:
            return pattern
        case .high:
            switch pattern {
            case .light: return .medium
            case .medium: return .heavy
            case .success: return .celebration
            case .failure: return .warning
            default: return pattern
            }
        }
    }
    
    // MARK: - Context-Specific Methods
    
    /// Play haptic when a set is completed
    func playSetCompleted() {
        play(.success)
    }
    
    /// Play haptic when a set is uncompleted
    func playSetUncompleted() {
        play(.light)
    }
    
    /// Play haptic when isometry count is finished (distinctive double tap)
    func playIsometryFinished() {
        play(.success, bypassThrottle: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.play(.heavy, bypassThrottle: true)
        }
    }
    
    /// Play haptic when failure is registered
    func playFailureRegistered() {
        play(.failure)
    }
    
    /// Play haptic when failure is removed
    func playFailureRemoved() {
        play(.light)
    }
    
    /// Play haptic when rest timer starts
    func playRestTimerStart() {
        play(.light)
    }
    
    /// Play haptic when rest timer finishes
    func playRestTimerFinished() {
        playCountdownFinal()
    }
    
    /// Play celebratory double-tap when PR is beaten
    func playPRBeaten() {
        play(.success, bypassThrottle: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.play(.celebration, bypassThrottle: true)
        }
    }
    
    /// Play haptic when workout starts
    func playWorkoutStart() {
        play(.medium)
    }
    
    /// Play celebratory double-tap when workout finishes
    func playWorkoutFinish() {
        play(.success, bypassThrottle: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            self?.play(.celebration, bypassThrottle: true)
        }
    }
    
    /// Play haptic when exercise changes
    func playExerciseChange() {
        play(.light)
    }
    
    /// Play haptic for crown rotation
    func playCrownRotation() {
        play(.light)
    }
    
    /// Play haptic for water intake
    func playWaterIntake() {
        play(.success)
    }
    
    /// Play haptic for error
    func playError() {
        play(.failure)
    }
    
    /// Play haptic when battery becomes critical
    func playBatteryCritical() {
        play(.warning)
    }
    
    /// Play haptic for rest timer countdown warning (3s, 2s, 1s)
    func playCountdownTick() {
        play(.medium, bypassThrottle: true)
    }
    
    /// Play distinctive double-tap when rest countdown hits 0
    func playCountdownFinal() {
        play(.reminder, bypassThrottle: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.play(.heavy, bypassThrottle: true)
        }
    }
    
    /// Play haptic when workout is cancelled
    func playWorkoutCancelled() {
        play(.failure)
    }

    // MARK: - Background / Wrist-Down Rest End Notification

    func scheduleRestEndNotification(endTimeMs: Int64, nextExerciseName: String) {
        guard hapticsEnabled else {
            cancelRestEndNotification()
            return
        }
        guard endTimeMs != lastScheduledRestEndTimeMs else { return }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let remainingSec = Double(endTimeMs - nowMs) / 1000.0
        guard remainingSec > 1.0 else {
            cancelRestEndNotification()
            return
        }

        lastScheduledRestEndTimeMs = endTimeMs
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restNotifId])

        let content = UNMutableNotificationContent()
        content.title = "⏱️ Descanso Concluído"
        content.body = nextExerciseName.isEmpty ? "Hora da próxima série!" : "Próximo: \(nextExerciseName)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingSec, repeats: false)
        let request = UNNotificationRequest(identifier: restNotifId, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                os_log("Error scheduling watch rest notification: %@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .error, error.localizedDescription)
            }
        }
    }

    func cancelRestEndNotification() {
        lastScheduledRestEndTimeMs = 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotifId])
    }
    
    // MARK: - Custom Patterns
    
    func playCustomPattern(patterns: [(HapticPattern, TimeInterval)]) {
        var delay: TimeInterval = 0
        
        for (pattern, patternDelay) in patterns {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(pattern, bypassThrottle: true)
            }
            delay += patternDelay
        }
    }
    
    func playRhythmicPattern(count: Int, interval: TimeInterval = 0.5) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * interval)) { [weak self] in
                self?.play(.light, bypassThrottle: true)
            }
        }
    }
    
    func playAcceleratingPattern(count: Int, baseInterval: TimeInterval = 0.3) {
        var delay: TimeInterval = 0
        
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(.light, bypassThrottle: true)
            }
            delay += baseInterval * (1.0 - Double(i) / Double(count))
        }
    }
    
    // MARK: - Haptic Settings
    
    private var hapticsEnabled = true
    private var currentIntensity = HapticIntensity.medium
    
    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            cancelRestEndNotification()
        }
        os_log("Haptics enabled: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, enabled ? 1 : 0)
    }
    
    func areHapticsEnabled() -> Bool {
        return hapticsEnabled
    }

    func setBatterySaverLowIntensity(_ active: Bool) {
        batterySaverLowIntensity = active
    }
    
    func setHapticIntensity(_ intensity: HapticIntensity) {
        currentIntensity = intensity
        UserDefaults.standard.set(intensity.rawValue, forKey: intensityKey)
        os_log("Haptic intensity set to: %@", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, intensity.rawValue)
    }
    
    func getHapticIntensity() -> HapticIntensity {
        return currentIntensity
    }

    /// Cycles: Normal -> Forte -> Leve -> Desligada -> Normal
    func cycleHapticMode() -> String {
        if !hapticsEnabled {
            setHapticsEnabled(true)
            setHapticIntensity(.medium)
            play(.medium, bypassThrottle: true)
        } else {
            switch currentIntensity {
            case .medium:
                setHapticIntensity(.high)
                play(.heavy, bypassThrottle: true)
            case .high:
                setHapticIntensity(.low)
                play(.light, bypassThrottle: true)
            case .low:
                setHapticsEnabled(false)
            }
        }
        return currentModeLabel()
    }

    func currentModeLabel() -> String {
        if !hapticsEnabled { return "Desligada" }
        return currentIntensity.label
    }
    
    func playWithIntensity(_ pattern: HapticPattern) {
        play(pattern)
    }
}
