//
//  CloudFlare_CheckerApp.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/7/1401 AP.
//

import SwiftUI

@main
struct CloudFlare_CheckerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
