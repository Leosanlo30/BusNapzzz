//
//  SettingsAndCacheTests.swift
//  BusNapTests
//

import Foundation
import Testing
@testable import BusNap

@MainActor
struct SettingsAndCacheTests {

    @Test("AppSettings persiste y recupera los valores")
    func testSettingsPersist() {
        let defaults = UserDefaults(suiteName: "BusNapTests.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.mapStyle = .satellite
        settings.vibrationEnabled = false
        settings.customLeadTimeMinutes = 7
        settings.travelMode = .walking

        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.mapStyle == .satellite)
        #expect(reloaded.vibrationEnabled == false)
        #expect(reloaded.customLeadTimeMinutes == 7)
        #expect(reloaded.travelMode == .walking)
    }

    @Test("Formatea distancias en la unidad elegida")
    func testDistanceFormatting() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "BusNapTests.\(UUID().uuidString)")!)

        settings.distanceUnit = .kilometers
        #expect(settings.formattedDistance(2_300).contains("km"))
        #expect(settings.formattedDistance(450).contains("m"))

        settings.distanceUnit = .miles
        #expect(settings.formattedDistance(5_000).contains("mi"))
    }

    @Test("La caché normaliza acentos y mayúsculas")
    func testCacheNormalizesQueries() {
        let cache = SearchResultCache(fileURL: nil)
        let result = PlaceResultFixture.make(name: "Plaza Grande")

        cache.store([result], for: "  Mérida  Centro ")

        #expect(cache.results(for: "merida centro")?.first?.name == "Plaza Grande")
    }

    @Test("La caché está acotada y descarta lo más antiguo")
    func testCacheIsBounded() {
        let cache = SearchResultCache(fileURL: nil, capacity: 2)
        cache.store([PlaceResultFixture.make(name: "A")], for: "a")
        cache.store([PlaceResultFixture.make(name: "B")], for: "b")
        cache.store([PlaceResultFixture.make(name: "C")], for: "c")

        #expect(cache.results(for: "a") == nil)
        #expect(cache.results(for: "c") != nil)
    }
}

@MainActor
enum PlaceResultFixture {
    static func make(name: String) -> PlaceResult {
        let json = """
        {"id":"place_\(name)","name":"\(name)","subtitle":"","latitude":20.97,"longitude":-89.62}
        """
        return try! JSONDecoder().decode(PlaceResult.self, from: Data(json.utf8))
    }
}
