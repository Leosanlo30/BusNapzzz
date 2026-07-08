# Módulo Core: TripMath

Este módulo forma parte del Core del proyecto y se encarga de centralizar toda la lógica matemática pura e independiente de estado para el cálculo de rutas, estimaciones de tiempo y optimización del ciclo de vida de la geolocalización.

---

## 🛠️ Implementación (`TripMath.swift`)

El módulo está diseñado utilizando un `enum` sin casos como *namespace* estático. Esto impide la instanciación accidental del módulo en memoria y asegura que todas las utilidades actúen como funciones puras, facilitando su reusabilidad y aislamiento.

```swift
import Foundation

/// Módulo de utilidades matemáticas para los cálculos de ruta y Adaptive Polling.
public enum TripMath {
    
    /// Calcula el tiempo de 'sleep' inicial para el algoritmo de Adaptive Polling.
    ///
    /// - Parameter eta: El tiempo estimado de llegada restante en segundos (TimeInterval).
    /// - Returns: El intervalo de espera recomendado en segundos. Garantiza nunca ser negativo.
    public static func calculateInitialSleep(for eta: TimeInterval) -> TimeInterval {
        // Validación de seguridad para evitar sleeps negativos ante anomalías del servidor o GPS
        guard eta > 0 else { return 0 }
        
        return eta / 2.0
    }
    
    /// Determina si el usuario ha entrado en el umbral crítico para preparar o disparar la alerta.
    ///
    /// - Parameters:
    ///   - eta: El tiempo estimado de llegada en segundos (TimeInterval).
    ///   - distance: La distancia restante al destino en metros (Double).
    /// - Returns: `true` si se cumple alguna de las condiciones críticas; de lo contrario, `false`.
    public static func isCriticalThresholdReached(eta: TimeInterval, distance: Double) -> Bool {
        let threeMinutesInSeconds: TimeInterval = 180.0
        let oneKilometerInMeters: Double = 1000.0
        
        // El umbral se activa si se cumple CUALQUIERA de los dos criterios (Compuerta OR)
        return eta <= threeMinutesInSeconds || distance <= oneKilometerInMeters
    }
}
