//
//  WatchAppApp.swift
//  WatchApp Watch App
//
//  Created by Wéllerson Vicente Rousselet Porfírio on 16/06/26.
//

import SwiftUI
import HealthKit
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate, WKExtensionDelegate {
    func applicationDidFinishLaunching() {
        WorkoutManager.shared.recoverOrphanedSession()
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // App launched by iOS app starting a workout
        print("[WatchApp] Launched via HKWorkoutConfiguration from iOS")
        WKInterfaceDevice.current().play(.success)
        WorkoutManager.shared.isLaunchedByiOS = true
        WorkoutManager.shared.startWorkout(configuration: workoutConfiguration)
        // Pull latest workout state from iPhone (application context may already be in flight).
        WatchConnectivityManager.shared.requestSync()
    }
}

@main
struct WatchApp_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WorkoutSelectionView()
                .onAppear {
                    WorkoutManager.shared.requestAuthorization()
                    WatchBackgroundSyncManager.setupBackgroundSync()
                }
        }
    }
}
