//
//  BusNapApp.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/06/26.
//

import SwiftUI

@main
struct BusNapApp: App {
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            MapDashboardView()
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme ?? nil)
        }
    }
}
