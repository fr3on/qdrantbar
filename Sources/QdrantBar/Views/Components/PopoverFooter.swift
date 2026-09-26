import SwiftUI
import QdrantBarCore

/// One quiet line of context plus a gear. Options stay hidden until needed.
struct PopoverFooter: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Button {
                Task { await appState.refreshAll() }
            } label: {
                if appState.isLoading {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .help("Refresh")

            if let checked = appState.lastChecked {
                (Text("Last checked ") + Text(checked, style: .relative) + Text(" ago"))
                    .font(.system(size: 11))
                    .lineLimit(1)
            } else {
                Text("Checking…").font(.system(size: 11))
            }

            Spacer()

            Menu {
                Button {
                    appState.openSettings()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)

                Button {
                    appState.launchOnboardingWindow()
                } label: {
                    Label("Connection Setup…", systemImage: "sparkles")
                }

                Divider()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit QdrantBar", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "gearshape").font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .foregroundColor(Theme.Colors.textMuted)
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
        }
    }
}
