import SwiftUI
import QdrantBarCore

struct AddServerView: View {
    @EnvironmentObject var appState: AppState

    private var needsOptIn: Bool { ConnectionPolicy.requiresInsecureOptIn(appState.newServerURL) }
    private var blockedUntilAllowed: Bool { needsOptIn && !appState.newServerAllowInsecure }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollingContent {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Text("Presets")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                        preset("Localhost", name: "Local Dev", url: "http://localhost:6333", env: "Development")
                        preset("Docker", name: "Docker", url: "http://127.0.0.1:6333", env: "Development")
                        preset("Cloud", name: "Qdrant Cloud", url: "https://your-cluster.cloud.qdrant.io:6333", env: "Production")
                    }

                    FormField(label: "Name", placeholder: "e.g. Local Dev, Prod Cluster", text: $appState.newServerName)
                    FormField(label: "Endpoint (REST)", placeholder: "http://localhost:6333", text: $appState.newServerURL, mono: true)
                    InsecureHTTPNotice(urlString: appState.newServerURL, allowed: $appState.newServerAllowInsecure)
                    FormField(label: "API key (optional)", placeholder: "Leave blank if no auth required", text: $appState.newServerApiKey, mono: true, secure: true)
                    FormEnvironmentPicker(selection: $appState.newServerEnvironment)

                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            Task {
                                await appState.testConnection(
                                    urlString: appState.newServerURL,
                                    apiKey: appState.newServerApiKey,
                                    allowInsecureHTTP: appState.newServerAllowInsecure
                                )
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if appState.isTestingConnection {
                                    ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                                } else {
                                    Image(systemName: "waveform.path.ecg").font(.system(size: 10, weight: .semibold))
                                }
                                Text(appState.isTestingConnection ? "Testing…" : "Test connection")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.pillBackground)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.isTestingConnection || appState.newServerURL.isEmpty)

                        TestResultLabel()
                    }
                }
                .padding(.horizontal, Theme.Layout.gutter)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }

            footer
        }
        .frame(width: Theme.Layout.popoverWidth, height: Theme.Layout.popoverHeight)
        .background(Theme.Colors.background)
        .onChange(of: appState.newServerURL) { _, _ in appState.resetTestResult() }
        .onChange(of: appState.newServerApiKey) { _, _ in appState.resetTestResult() }
        .onChange(of: appState.newServerAllowInsecure) { _, _ in appState.resetTestResult() }
    }

    private var header: some View {
        HStack {
            Button {
                appState.navigateToManageServers()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Servers").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Theme.Colors.textMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .overlay {
            Text("Add server")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Button {
                appState.navigateToManageServers()
            } label: {
                Text("Cancel")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                appState.addServer(
                    name: appState.newServerName.isEmpty ? "Qdrant Server" : appState.newServerName,
                    urlString: appState.newServerURL.isEmpty ? "http://localhost:6333" : appState.newServerURL,
                    apiKey: appState.newServerApiKey,
                    environmentTag: appState.newServerEnvironment,
                    allowInsecureHTTP: appState.newServerAllowInsecure
                )
                appState.navigateToDashboard()
            } label: {
                PrimaryPillLabel(title: "Save & connect")
                    .opacity(blockedUntilAllowed ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(blockedUntilAllowed)
            .help(blockedUntilAllowed ? "Allow insecure HTTP first, or use https." : "")
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
        }
    }

    private func preset(_ title: String, name: String, url: String, env: String) -> some View {
        Button {
            appState.newServerName = name
            appState.newServerURL = url
            appState.newServerEnvironment = env
        } label: {
            PillLabel(text: title)
        }
        .buttonStyle(.plain)
    }
}

/// The outcome of "Test connection", shared by onboarding and Add Server. Wraps onto several lines,
/// because the friendly errors are sentences.
struct TestResultLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let result = appState.testConnectionResult {
            let success = appState.testConnectionSuccess == true
            let color = success ? Theme.Colors.statusGreen : (appState.testConnectionNeedsKey ? Theme.Colors.statusYellow : Theme.Colors.statusRed)
            HStack(alignment: .top, spacing: 6) {
                StatusDot(color: color, size: 7).padding(.top, 4)
                Text(result)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
