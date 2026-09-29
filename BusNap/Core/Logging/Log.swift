//
//  Log.swift
//  BusNap
//

import OSLog

/// Loggers unificados por subsistema. Sustituyen a `print` para que los
/// mensajes se filtren en Console.app y los datos sensibles (nombres de
/// destino, coordenadas) se marquen como privados.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.busnap.app"

    static let trip = Logger(subsystem: subsystem, category: "trip")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let search = Logger(subsystem: subsystem, category: "search")
}
