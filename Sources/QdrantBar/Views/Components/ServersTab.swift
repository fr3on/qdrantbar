import SwiftUI
import QdrantBarCore

struct ServersTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(appState.servers) { server in
                    row(server)
                    if server.id != appState.servers.last?.id {
                        Rectangle()
                            .fill(Theme.Colors.border)
                            .frame(height: 1)
                            .padding(.leading, Theme.Layout.gutter + 17)
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    appState.navigateToAddServer()
                } label: {
                    PrimaryPillLabel(title: "Add server")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Layout.gutter)
            .padding(.top, 14)
        }
    }

    private func row(_ server: ServerProfile) -> some View {
        let active = appState.activeServerId == server.id
        return HStack(spacing: 10) {
            StatusDot(color: active ? Theme.Colors.statusGreen : Theme.Colors.statusGray, size: 7)

            Button {
                appState.switchServer(to: server)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        PillLabel(text: server.environmentTag)
                        if server.isInsecureRemote {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.open.fill").font(.system(size: 8))
                                Text("http").font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(Theme.Colors.statusYellow)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.pillBackground)
                            .clipShape(Capsule())
                            .help("Plain HTTP is allowed for this server")
                        }
                    }
                    Text(Format.host(server.urlString))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(active ? "Active server" : "Switch to this server")

            if active {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
            } else if appState.servers.count > 1 {
                Button {
                    appState.deleteServer(id: server.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Delete this server profile")
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, Theme.Layout.gutter)
    }
}
