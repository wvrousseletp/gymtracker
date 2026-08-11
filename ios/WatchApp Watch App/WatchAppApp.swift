//
//  WatchAppApp.swift
//  WatchApp Watch App
//
//  Created by Wéllerson Vicente Rousselet Porfírio on 16/06/26.
//

import SwiftUI
import HealthKit
import WatchKit
import UserNotifications

class ExtensionDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        // Delay session recovery to avoid crashing during early launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
            guard HKHealthStore.isHealthDataAvailable() else { return }
            WorkoutManager.shared.recoverOrphanedSession()
        }
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // App launched by iOS app starting a workout
        print("[WatchApp] Launched via HKWorkoutConfiguration from iOS")
        WorkoutManager.shared.isLaunchedByiOS = true
        
        // Use the EXACT configuration provided by iOS to claim the session placeholder
        WorkoutManager.shared.startWorkout(configuration: workoutConfiguration)
        
        // Trigger a local notification to alert the user in watchOS 10+
        let content = UNMutableNotificationContent()
        content.title = "🏋️ Treino Iniciado"
        content.body = "Toque para ver o treino atual."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[WatchApp] Error scheduling notification: \(error)")
            }
        }
        
        // Pull latest workout state from iPhone (application context may already be in flight).
        DispatchQueue.main.async {
            WatchConnectivityManager.shared.requestSync()
        }
    }
    
    // Hide notifications if the app is already in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

@main
struct WatchApp_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WorkoutSelectionView()
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        WatchConnectivityManager.shared.checkAndResetDailyWater()
                    }
                }
                .onAppear {
                    DispatchQueue.global(qos: .utility).async {
                        WorkoutManager.shared.requestAuthorization()
                    }
                    
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        print("[WatchApp] Notifications granted on appear: \(granted)")
                    }
                }
        }
    }
}
