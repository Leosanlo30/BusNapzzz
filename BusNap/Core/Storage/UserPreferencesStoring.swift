//
//  UserPreferencesStoring.swift.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

protocol UserPreferencesStoring: Sendable {
    func saveLeadTime(_ time: AlertLeadTime)
    func loadLeadTime() -> AlertLeadTime
}
