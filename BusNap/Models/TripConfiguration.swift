//
//  TripConfiguration.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 07/07/26.
//

import Foundation

struct TripConfiguration: Equatable, Codable {
    var destination: Destination
    var leadTime: AlertLeadTime
    var status: AlarmStatus
    
    init(
        destination: Destination,
        leadTime: AlertLeadTime = .fiveMinutes,
        status: AlarmStatus = .configured
    ) {
        self.destination = destination
        self.leadTime = leadTime
        self.status = status
    }
    
    // Función pura para mutar el estado sin romper la inmutabilidad de la estructura base
    func updatingStatus(to newStatus: AlarmStatus) -> TripConfiguration {
        var copy = self
        copy.status = newStatus
        return copy
    }
}
