//
//  WatchAppApp.swift
//  WatchApp Watch App
//
//  Created by Wéllerson Vicente Rousselet Porfírio on 16/06/26.
//

import SwiftUI

@main
struct WatchApp_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            WorkoutSelectionView()
                .onAppear {
                    WorkoutManager.shared.requestAuthorization()
                }
        }
    }
}
