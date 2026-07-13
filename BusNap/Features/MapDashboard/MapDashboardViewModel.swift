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
    var selectedDestination: Destination? = nil
    var leadTime: AlertLeadTime = .fiveMinutes
    var simulatedETA: Int? = nil

    // MARK: - Configuración de Viaje (persiste entre sesiones)

    var vibrateEnabled: Bool = true {
        didSet { UserDefaults.standard.set(vibrateEnabled, forKey: "vibrateEnabled") }
    }
    var selectedRingtone: String = "Default" {
        didSet { UserDefaults.standard.set(selectedRingtone, forKey: "selectedRingtone") }
    }
    var appTheme: AppTheme = .system {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    var showDebugOverlay: Bool = false
    
    // MARK: - Inicializador (carga configuración guardada)

    init() {
        UserDefaults.standard.register(defaults: [
            "vibrateEnabled": true,
            "selectedRingtone": "Default",
            "appTheme": AppTheme.system.rawValue
        ])
        vibrateEnabled    = UserDefaults.standard.bool(forKey: "vibrateEnabled")
        selectedRingtone  = UserDefaults.standard.string(forKey: "selectedRingtone") ?? "Default"
        appTheme          = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system

        if let data  = UserDefaults.standard.data(forKey: "leadTime"),
           let saved = try? JSONDecoder().decode(AlertLeadTime.self, from: data) {
            leadTime = saved
        }
    }

    // MARK: - Intenciones (Mutaciones de Estado)
    
    /// Actualiza el destino seleccionado por el usuario
    func updateDestination(_ destination: Destination) {
        self.selectedDestination = destination
    }
    
    /// Modifica el tiempo de anticipación para la alarma y lo persiste
    func updateLeadTime(_ time: AlertLeadTime) {
        self.leadTime = time
        if let data = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(data, forKey: "leadTime")
        }
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

    /// Apaga la alarma cuando está sonando y regresa al estado inicial
    func dismissAlarm() {
        alarmStatus = .inactive
        selectedDestination = nil
        simulatedETA = nil
        print("Alarma apagada.")
    }
}
