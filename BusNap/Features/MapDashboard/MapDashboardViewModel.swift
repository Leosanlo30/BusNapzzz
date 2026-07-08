//
//  MapDashboardViewModel.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import Observation

@Observable //Para que el programa actualice por si misma la pantala cada que se cambie de estado
class MapDashboardViewModel {
    
    // MARK: - Estado de la Interfaz (Propiedades)
    
    var alarmStatus: AlarmStatus = .inactive
    var selectedDestination: Destination? = nil //opcional al princio (iniciar la app)
    var leadTime: AlertLeadTime = .fiveMinutes
    var simulatedETA: Int? = nil // Representado en minutos | opcional al princio (iniciar la app)
    
    // MARK: - Intenciones (Mutaciones de Estado)
    
    /// Actualiza el destino seleccionado por el usuario
    func updateDestination(_ destination: Destination) {
        self.selectedDestination = destination
    }
    
    /// Modifica el tiempo de anticipación para la alarma
    func updateLeadTime(_ time: AlertLeadTime) {
        self.leadTime = time
    }
    
    /// Inicia el flujo de viaje, simulando la transición de estados
    func activateTrip() {
        // Bloqueo de seguridad: no podemos activar sin destino
        guard selectedDestination != nil else {
            print("Error: Intento de activar viaje sin destino.")
            return
        }
        
        // Pasamos al estado configurado
        alarmStatus = .configured
        
        //Simulamos que el motor arranca y pasamos a monitorear
        //inicio del loop principal.
        alarmStatus = .monitoring
        
        // Simulamos un ETA inicial (ej. 45 minutos)
        simulatedETA = 45
        
        print("Viaje activado hacia: \(selectedDestination?.name ?? "Desconocido")")
    }
    
    /// Cancela el viaje activo y resetea los valores al estado inactivo
    func cancelTrip() {
        alarmStatus = .inactive
        selectedDestination = nil
        simulatedETA = nil
        
        print("Viaje cancelado. Sistema inactivo.")
    }
}
