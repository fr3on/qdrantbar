import Foundation
import Testing
@testable import QdrantBarCore

@Suite("App settings")
struct SettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "qdrantbar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Defaults: points next to the icon, 10 s open, 30 s background")
    func defaults() {
        let settings = AppSettings()
        #expect(settings.menuBarStat == .points)
        #expect(settings.hideStatWhenOffline)
        #expect(settings.openRefreshSeconds == 10)
        #expect(settings.backgroundRefreshSeconds == 30)
        #expect(AppSettings.load(from: freshDefaults()) == settings)
    }

    @Test("Settings round-trip through defaults")
    func roundTrip() {
        let defaults = freshDefaults()
        let settings = AppSettings(menuBarStat: .latency, hideStatWhenOffline: false, openRefreshSeconds: 30, backgroundRefreshSeconds: 0)
        settings.save(to: defaults)
        #expect(AppSettings.load(from: defaults) == settings)
    }

    @Test("A partial or unknown blob keeps the other defaults")
    func partial() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"menuBarStat":"collections"}"#.utf8))
        #expect(decoded.menuBarStat == .collections)
        #expect(decoded.openRefreshSeconds == 10)
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"menuBarStat":"sparkles","openRefreshSeconds":30}"#.utf8))
        #expect(unknown.menuBarStat == .points)
        #expect(unknown.openRefreshSeconds == 30)
    }

    @Test("Intervals snap to the offered choices, so a bad value cannot hammer a server")
    func normalization() {
        let bad = AppSettings(openRefreshSeconds: 1, backgroundRefreshSeconds: 7).normalized()
        #expect(bad.openRefreshSeconds == 5)
        #expect(bad.backgroundRefreshSeconds == 0)
        #expect(AppSettings(openRefreshSeconds: 999, backgroundRefreshSeconds: 999).normalized().backgroundRefreshSeconds == 300)
        let defaults = freshDefaults()
        defaults.set(Data(#"{"openRefreshSeconds":0}"#.utf8), forKey: AppSettings.storageKey)
        #expect(AppSettings.load(from: defaults).openRefreshSeconds == 5)
    }
}

@Suite("Menu bar display")
struct MenuBarDisplayTests {
    private func input(_ connection: ConnectionState, degraded: Bool = false) -> MenuBarDisplay.Input {
        .init(connection: connection, hasDegradedCollections: degraded, totalPoints: 3300, latencyMs: 43.6, collectionCount: 3, serverName: "Local Dev")
    }

    @Test("Online shows the chosen stat")
    func online() {
        #expect(MenuBarDisplay.make(input(.online), settings: AppSettings(menuBarStat: .points)).text == "3.3k")
        #expect(MenuBarDisplay.make(input(.online), settings: AppSettings(menuBarStat: .latency)).text == "44 ms")
        #expect(MenuBarDisplay.make(input(.online), settings: AppSettings(menuBarStat: .collections)).text == "3")
        #expect(MenuBarDisplay.make(input(.online), settings: AppSettings(menuBarStat: .none)).text == nil)
    }

    @Test("Degraded keeps the stat but changes state")
    func degraded() {
        let display = MenuBarDisplay.make(input(.online, degraded: true), settings: AppSettings())
        #expect(display.state == .degraded)
        #expect(display.text == "3.3k")
    }

    @Test("A locked server shows a key hint, whatever the stat, unless icon only")
    func unauthorized() {
        #expect(MenuBarDisplay.make(input(.unauthorized), settings: AppSettings(menuBarStat: .latency)).text == "key")
        #expect(MenuBarDisplay.make(input(.unauthorized), settings: AppSettings(menuBarStat: .none)).text == nil)
        #expect(MenuBarDisplay.make(input(.unauthorized), settings: AppSettings()).state == .unauthorized)
    }

    @Test("Offline hides the text by default, and says off when asked")
    func offline() {
        #expect(MenuBarDisplay.make(input(.offline), settings: AppSettings()).text == nil)
        #expect(MenuBarDisplay.make(input(.offline), settings: AppSettings(hideStatWhenOffline: false)).text == "off")
        #expect(MenuBarDisplay.make(input(.offline), settings: AppSettings(menuBarStat: .none, hideStatWhenOffline: false)).text == nil)
    }

    @Test("Latency is not shown when it is unknown")
    func noLatency() {
        var value = input(.online)
        value.latencyMs = nil
        #expect(MenuBarDisplay.make(value, settings: AppSettings(menuBarStat: .latency)).text == nil)
    }

    @Test("Compact counts")
    func compact() {
        #expect(MenuBarDisplay.compactCount(0) == "0")
        #expect(MenuBarDisplay.compactCount(999) == "999")
        #expect(MenuBarDisplay.compactCount(1_000) == "1.0k")
        #expect(MenuBarDisplay.compactCount(1_714_998) == "1.7M")
    }

    @Test("The tooltip names the server, state and numbers")
    func tooltip() {
        #expect(MenuBarDisplay.make(input(.online), settings: AppSettings()).tooltip == "QdrantBar · Local Dev · Online · 3300 points · 44 ms")
        #expect(MenuBarDisplay.make(input(.unauthorized), settings: AppSettings()).tooltip == "QdrantBar · Local Dev · Needs API key")
    }
}
