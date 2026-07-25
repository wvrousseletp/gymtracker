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

class ExtensionDelegate: NSObject, WKApplicationDelegate, WKExtensionDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        WorkoutManager.shared.recoverOrphanedSession()
        UNUserNotificationCenter.current().delegate = self
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // App launched by iOS app starting a workout
        print("[WatchApp] Launched via HKWorkoutConfiguration from iOS")
        WKInterfaceDevice.current().play(.success)
        WorkoutManager.shared.isLaunchedByiOS = true
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
        WatchConnectivityManager.shared.requestSync()
    }
    
    // Ensure notification shows even if app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
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
                    WorkoutManager.shared.requestAuthorization()
                    WatchBackgroundSyncManager.setupBackgroundSync()
                    
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        print("[WatchApp] Notifications granted on appear: \(granted)")
                    }
                }
        }
    }
}
