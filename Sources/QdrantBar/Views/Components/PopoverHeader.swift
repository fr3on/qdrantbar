import SwiftUI
import QdrantBarCore

/// Logo, server picker and environment tag.
struct PopoverHeader: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.brandGradient)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                )

            Menu {
                Section("Active Server") {
                    ForEach(appState.servers) { server in
                        Button {
                            appState.switchServer(to: server)
                        } label: {
                            HStack {
                                if appState.activeServerId == server.id {
                                    Image(systemName: "checkmark")
                                }
                                Text("\(server.name) (\(server.environmentTag))")
                            }
                        }
                    }
                }
                Divider()
                Button {
                    appState.navigateToAddServer()
                } label: {
                    Label("Add Server…", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(appState.activeServer.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()

            PillLabel(text: appState.activeServer.environmentTag)
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 14)
    }
}
