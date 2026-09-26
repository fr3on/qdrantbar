import SwiftUI
import QdrantBarCore

/// One number, one state line, one action. Nothing else competes with it.
struct HeroView: View {
    @EnvironmentObject var appState: AppState

    private var degraded: Bool { appState.degradedCollectionsCount > 0 }

    private var stateText: String {
        switch appState.connection {
        case .online: return degraded ? "Degraded" : "Online"
        case .unauthorized: return "Not authorized"
        case .offline: return "Offline"
        }
    }

    private var stateColor: Color {
        switch appState.connection {
        case .online: return degraded ? Theme.Colors.statusYellow : Theme.Colors.statusGreen
        case .unauthorized: return Theme.Colors.statusYellow
        case .offline: return Theme.Colors.statusGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch appState.connection {
                case .online:
                    Text(Format.count(appState.totalPoints))
                        .font(Theme.Typography.heroNumber)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(appState.totalPoints == 1 ? "point" : "points")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textMuted)
                case .unauthorized:
                    Text("Locked")
                        .font(Theme.Typography.heroNumber)
                        .foregroundColor(Theme.Colors.textPrimary)
                case .offline:
                    Text("Offline")
                        .font(Theme.Typography.heroNumber)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                Spacer()

                if appState.isHealthy {
                    Button {
                        appState.openDashboard()
                    } label: {
                        QuietPillLabel(title: "Dashboard", icon: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                    .help("Open the Qdrant web dashboard")
                }
            }

            HStack(spacing: 7) {
                StatusDot(color: stateColor)
                Text(stateText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)

                if appState.isHealthy {
                    Text(detailText)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    if appState.activeServerIsInsecure {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.statusYellow)
                            .help("Plain HTTP is allowed for this server: traffic is not encrypted")
                    }
                    Text(Format.host(appState.hostURLString))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var detailText: String {
        var parts: [String] = []
        if let version = appState.version { parts.append("v\(version.version)") }
        if let latency = appState.latencyMs { parts.append(String(format: "%.0f ms", latency)) }
        return parts.joined(separator: " · ")
    }
}
