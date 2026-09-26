import SwiftUI
import QdrantBarCore

/// Preferences, opened inside the popover like Add server. Every change is saved as soon as it is made.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollingContent {
                VStack(alignment: .leading, spacing: 0) {
                    menuBarGroup
                    refreshGroup
                    generalGroup
                    serversGroup
                    privacyGroup
                    aboutGroup
                }
                .padding(.bottom, 14)
            }

            Text("Changes save instantly")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Layout.gutter)
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                }
        }
        .frame(width: Theme.Layout.popoverWidth, height: Theme.Layout.popoverHeight)
        .background(Theme.Colors.background)
    }

    private var header: some View {
        HStack {
            Button {
                appState.closeSettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Back").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Theme.Colors.textMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .overlay {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: Menu bar

    private var menuBarGroup: some View {
        SettingsGroup(title: "Menu bar") {
            HStack {
                Spacer()
                Image(nsImage: MenuBarImage.make(appState.menuBarDisplay))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .help(appState.menuBarDisplay.tooltip)
                Spacer()
            }
            .padding(.vertical, 6)

            SettingRow(title: "Show next to the icon") {
                SelectPill(
                    selection: $appState.settings.menuBarStat,
                    options: AppSettings.MenuBarStat.allCases.map { ($0, $0.title) }
                )
            }
            SettingRow(title: "Icon and dot only when offline", detail: "Hide the number while the server is unreachable") {
                SwitchControl(isOn: $appState.settings.hideStatWhenOffline, tint: Theme.Colors.accent, accessibilityName: "Icon and dot only when offline")
            }
        }
    }

    // MARK: Refresh

    private var refreshGroup: some View {
        SettingsGroup(title: "Refresh") {
            SettingRow(title: "While the popover is open") {
                SelectPill(
                    selection: $appState.settings.openRefreshSeconds,
                    options: AppSettings.openRefreshChoices.map { ($0, "\($0) s") }
                )
            }
            SettingRow(
                title: "In the background",
                detail: appState.settings.backgroundRefreshSeconds == 0
                    ? "Off: the menu bar item updates only while the popover is open."
                    : "Keeps the menu bar item current. Only checks /healthz."
            ) {
                SelectPill(
                    selection: $appState.settings.backgroundRefreshSeconds,
                    options: AppSettings.backgroundRefreshChoices.map { ($0, Self.backgroundTitle($0)) }
                )
            }
        }
    }

    private static func backgroundTitle(_ seconds: Int) -> String {
        switch seconds {
        case 0: return "Off"
        case ..<60: return "\(seconds) s"
        default: return "\(seconds / 60) min"
        }
    }

    // MARK: General, servers

    private var generalGroup: some View {
        SettingsGroup(title: "General") {
            SettingRow(title: "Launch at login", detail: appState.launchAtLoginMessage) {
                SwitchControl(isOn: $appState.launchAtLogin, tint: Theme.Colors.accent, accessibilityName: "Launch at login")
            }
            SettingRow(title: "Appearance") {
                SelectPill(
                    selection: $appState.themeMode,
                    options: AppThemeMode.allCases.map { ($0, $0.rawValue) }
                )
            }
        }
    }

    private var serversGroup: some View {
        SettingsGroup(title: "Servers") {
            Button {
                appState.selectedTab = .servers
                appState.closeSettings()
            } label: {
                SettingRow(title: "Manage servers", detail: "Add, switch, delete, and see which allow insecure HTTP") {
                    HStack(spacing: 6) {
                        Text("\(appState.servers.count)")
                            .font(.system(size: 12.5).monospacedDigit())
                            .foregroundColor(Theme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Privacy, about

    private var privacyGroup: some View {
        SettingsGroup(title: "Privacy") {
            Text("API keys stay in your Keychain. No analytics or tracking: QdrantBar only talks to the servers you add.")
                .font(.system(size: 11.5))
                .foregroundColor(Theme.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Layout.gutter)

            Button {
                appState.launchOnboardingWindow()
            } label: {
                SettingRow(title: "Show setup again") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutGroup: some View {
        SettingsGroup(title: "About") {
            SettingRow(title: "QdrantBar", detail: "Version \(Self.version) · Unofficial, not affiliated with Qdrant") {
                EmptyView()
            }
            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    QuietPillLabel(title: "Quit QdrantBar", icon: "power")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, Theme.Layout.gutter)
            .padding(.top, 6)
        }
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
