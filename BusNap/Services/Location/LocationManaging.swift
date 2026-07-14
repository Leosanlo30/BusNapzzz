//
//  LocationManaging.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import MapKit
import CoreLocation


// Exigimos que cualquier manejador de ubicación opere bajo la protección del hilo de UI
@MainActor
protocol LocationManaging {
    var permissionState: LocationPermissionState { get }
    func requestWhenInUseAuthorization() // Autorizacion CUANDO SE USA
    func requestAlwaysAuthorization() //Autorizacion SIEMPRE
    
    /* MODO AHORRO */
    func enableEcoMode()
    func disableEcoMode()
    
    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) //comunicación para enviar las coordenadas al ViewModel
}
