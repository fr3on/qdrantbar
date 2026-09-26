import SwiftUI
import AppKit
import QdrantBarCore

@main
struct QdrantBarApp: App {
    @StateObject private var appState = AppState()

    init() {
        #if DEBUG
        MainActor.assumeIsolated { Snapshot.runIfRequested() }
        #endif
        quitIfAlreadyRunning()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            Image(nsImage: MenuBarImage.make(appState.menuBarDisplay))
                .help(appState.menuBarDisplay.tooltip)
        }
        .menuBarExtraStyle(.window)
    }
}

private func quitIfAlreadyRunning() {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.0x200.qdrantbar"
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    if running.count > 1 {
        exit(0)
    }
}
