import Foundation
import os.log
#if os(watchOS)
import WatchKit
#endif

class WatchHapticManager {
    static let shared = WatchHapticManager()
    
    private init() {}
    
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
    
    // MARK: - Public Methods
    
    func play(_ pattern: HapticPattern) {
        guard hapticsEnabled else { return }
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        switch pattern {
        case .success:
            device.play(.success)
            
        case .failure:
            device.play(.directionDown)
            
        case .reminder:
            device.play(.notification)
            
        case .celebration:
            device.play(.directionUp)
            
        case .warning:
            device.play(.failure)
            
        case .light:
            device.play(.click)
            
        case .medium:
            device.play(.success)
            
        case .heavy:
            device.play(.notification)
        }
        
        os_log("Played haptic pattern: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, pattern.hashValue)
        #endif
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
    
    /// Play haptic when isometry count is finished (intense vibration)
    func playIsometryFinished() {
        play(.warning)
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
        play(.reminder)
    }
    
    /// Play haptic when PR is beaten
    func playPRBeaten() {
        play(.celebration)
    }
    
    /// Play haptic when workout starts
    func playWorkoutStart() {
        play(.medium)
    }
    
    /// Play haptic when workout finishes
    func playWorkoutFinish() {
        play(.celebration)
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
        play(.warning)
    }
    
    /// Play haptic when battery becomes critical
    func playBatteryCritical() {
        play(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.play(.warning)
        }
    }
    
    /// Play haptic for rest timer countdown warning (3s, 2s, 1s)
    func playCountdownTick() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// Play haptic when rest countdown hits 0 (strong double pulse)
    func playCountdownFinal() {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            device.play(.success)
        }
        #endif
    }

    /// Play haptic when workout is cancelled
    func playWorkoutCancelled() {
        play(.failure)
    }
    
    // MARK: - Custom Patterns
    
    /// Play custom haptic pattern with specified delays
    func playCustomPattern(patterns: [(HapticPattern, TimeInterval)]) {
        var delay: TimeInterval = 0
        
        for (pattern, patternDelay) in patterns {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(pattern)
            }
            delay += patternDelay
        }
    }
    
    /// Play rhythmic pattern (e.g., for countdown)
    func playRhythmicPattern(count: Int, interval: TimeInterval = 0.5) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * interval)) { [weak self] in
                self?.play(.light)
            }
        }
    }
    
    /// Play accelerating pattern (e.g., for urgency)
    func playAcceleratingPattern(count: Int, baseInterval: TimeInterval = 0.3) {
        var delay: TimeInterval = 0
        
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(.light)
            }
            delay += baseInterval * (1.0 - Double(i) / Double(count))
        }
    }
    
    // MARK: - Haptic Settings
    
    private var hapticsEnabled = true
    
    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        os_log("Haptics enabled: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, enabled ? 1 : 0)
    }
    
    func areHapticsEnabled() -> Bool {
        return hapticsEnabled
    }
    
    // MARK: - Intensity Control
    
    enum HapticIntensity {
        case low
        case medium
        case high
    }
    
    private var currentIntensity = HapticIntensity.medium
    
    func setHapticIntensity(_ intensity: HapticIntensity) {
        currentIntensity = intensity
        os_log("Haptic intensity set to: %d", log: OSLog(subsystem: "com.losmooscles.watch", category: "Haptic"), type: .info, intensity.hashValue)
    }
    
    func getHapticIntensity() -> HapticIntensity {
        return currentIntensity
    }
    
    // MARK: - Play with Intensity
    
    func playWithIntensity(_ pattern: HapticPattern) {
        guard hapticsEnabled else { return }
        
        switch currentIntensity {
        case .low:
            // Reduce intensity by using lighter patterns
            switch pattern {
            case .success, .medium:
                play(.light)
            case .celebration, .heavy:
                play(.medium)
            case .failure, .warning:
                play(.light)
            default:
                play(pattern)
            }
            
        case .medium:
            // Normal intensity
            play(pattern)
            
        case .high:
            // Increase intensity by using stronger patterns
            switch pattern {
            case .light, .medium:
                play(.heavy)
            case .success:
                play(.celebration)
            case .failure:
                play(.warning)
            default:
                play(pattern)
            }
        }
    }
}
