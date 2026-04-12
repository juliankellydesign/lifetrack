//
//  lifetrackApp.swift
//  lifetrack
//
//  Created by Julian Kelly on 4/11/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct lifetrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if canImport(UIKit)
                    UIApplication.shared.isIdleTimerDisabled = true
                    #endif
                }
        }
    }
}
