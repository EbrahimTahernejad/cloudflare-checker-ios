//
//  CloudFlare_CheckerApp.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/7/1401 AP.
//

import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    
}

@main
struct CloudFlareCheckerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.managedObjectContext,
                     persistenceController.container.viewContext
                )
        }
    }
}
