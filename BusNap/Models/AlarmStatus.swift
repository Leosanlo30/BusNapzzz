//
//  AlarmStatus.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 23/06/26.
//

import Foundation

//Tipo de dato del Estado de la alarma
enum AlarmStatus: Equatable {
    case inactive
    case configured
    case monitoring
    case criticalZone
    case triggered
    case cancelled
    
    //Devuelve true si el viaje esta en progreso y false si no lo
    var isActiveTrip: Bool {
        switch self {
        case .monitoring, .criticalZone:
            return true
        default:
            return false
        }
    }
    
    //Mensaje para la UI
    var displayStatus: String{
        
    switch self {
    case .inactive:
        return "Inactiva"
    case .configured:
        return "Viaje configurado"
    case .monitoring:
        return "Monitoreando ruta..."
    case .criticalZone:
        return "Llegando al destino"
    case .triggered:
        return "Despierta"
    case .cancelled:
        return "Viaje cancelado"
        }
       
    }
    
    
    
    }


