//
//  BusNapFlowUITests.swift
//  BusNapUITests
//
//  Flujos de punta a punta desde un estado limpio (permisos sin decidir).
//  Si el hilo principal se bloquea, XCUITest no logra obtener la jerarquía
//  de la app y la prueba falla por tiempo de espera.
//

import XCTest

final class BusNapFlowUITests: XCTestCase {

    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
    }

    // MARK: - Helpers

    /// Pulsa un botón de una alerta del sistema si aparece.
    @discardableResult
    private func tapSystemAlert(_ labels: [String], timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in labels {
                let button = springboard.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            usleep(200_000)
        }
        return false
    }

    private var searchField: XCUIElement { app.textFields["¿A dónde vas?"] }

    private func assertResponsive(_ element: XCUIElement, _ message: String,
                                  timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(message) (no interactuable)", file: file, line: line)
    }

    // MARK: - Tests

    @MainActor
    func testFreshLaunchIsResponsive() {
        app.launch()
        tapSystemAlert(["Permitir al usar la app", "Allow While Using App"])

        assertResponsive(searchField, "La barra de búsqueda debe aparecer tras el arranque")
        searchField.tap()
        searchField.typeText("Plaza")
        XCTAssertEqual(searchField.value as? String, "Plaza", "El campo debe aceptar texto sin congelarse")
    }

    @MainActor
    func testFreshLaunchWithPermissionDeniedIsResponsive() {
        app.launch()
        tapSystemAlert(["No permitir", "Don’t Allow", "Don't Allow"])

        assertResponsive(searchField, "La app debe seguir usable sin permiso de ubicación")
        assertResponsive(app.buttons["Configuración"], "El botón de ajustes debe responder")
        app.buttons["Configuración"].tap()
        assertResponsive(app.buttons["Listo"], "Ajustes debe abrirse")
        app.buttons["Listo"].tap()
        assertResponsive(searchField, "Debe volver al mapa")
    }

    @MainActor
    func testFullTripFlow() {
        app.launch()
        tapSystemAlert(["Permitir al usar la app", "Allow While Using App"])
        assertResponsive(searchField, "Mapa listo")

        // Elegir destino tocando el mapa.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        let start = app.buttons["Iniciar viaje"]
        assertResponsive(start, "Tocar el mapa debe abrir la configuración del viaje")

        // Iniciar: pide "Siempre" y el viaje arranca al concederlo.
        start.tap()
        tapSystemAlert(["Cambiar a Permitir siempre", "Change to Always Allow",
                        "Permitir siempre", "Always Allow"])
        tapSystemAlert(["Permitir", "Allow"], timeout: 5) // notificaciones

        let finish = app.buttons["Terminar"]
        assertResponsive(finish, "El viaje debe quedar activo", timeout: 15)

        finish.tap()
        assertResponsive(searchField, "Terminar debe volver a la búsqueda")
    }
}
