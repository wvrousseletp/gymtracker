//
//  WatchAppApp.swift
//  WatchApp Watch App
//
//  Created by Wéllerson Vicente Rousselet Porfírio on 16/06/26.
//

import SwiftUI
import HealthKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidFinishLaunching() {
        WorkoutManager.shared.recoverOrphanedSession()
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // App launched by iOS app starting a workout
        print("[WatchApp] Launched via HKWorkoutConfiguration from iOS")
        WorkoutManager.shared.isLaunchedByiOS = true
        WorkoutManager.shared.startWorkout()
    }
}

@main
struct WatchApp_Watch_AppApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WorkoutSelectionView()
                .onAppear {
                    WorkoutManager.shared.requestAuthorization()
                }
        }
    }
}
