import SwiftUI
import QdrantBarCore

struct OnboardingWindowView: View {
    @EnvironmentObject var appState: AppState

    static let size = CGSize(width: 560, height: 500)

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The real traffic lights sit at the leading edge; the steps are centered.
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        stepDot(active: appState.onboardingStep == index)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)

                Group {
                    switch appState.onboardingStep {
                    case 0:
                        welcomeStep
                    case 1:
                        connectStep
                    default:
                        connectedStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .preferredColorScheme(appState.themeMode == .system ? nil : (appState.themeMode == .dark ? .dark : .light))
    }

    private func stepDot(active: Bool) -> some View {
        Capsule()
            .fill(active ? Theme.Colors.accent : Theme.Colors.pillBackground)
            .frame(width: active ? 22 : 7, height: 7)
            .animation(.easeInOut(duration: 0.2), value: active)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.Colors.brandGradient)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                )
                .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 14, y: 6)

            Text("Welcome to QdrantBar")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, 16)

            Text("See what your Qdrant server is doing, right from the menu bar.")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, 5)

            HStack(spacing: 10) {
                featureCard(
                    icon: "eye",
                    title: "Monitor only",
                    text: "Reads status and collections. It never starts, stops or changes anything."
                )
                featureCard(
                    icon: "server.rack",
                    title: "Any server",
                    text: "Switch between local, staging and Qdrant Cloud in one click."
                )
                featureCard(
                    icon: "lock.shield",
                    title: "Private",
                    text: "API keys stay in your Keychain. No analytics, ever."
                )
            }
            .frame(height: 132)
            .padding(.top, 26)

            Spacer(minLength: 0)

            Button {
                withAnimation { appState.onboardingStep = 1 }
            } label: {
                PrimaryPillLabel(title: "Get started  →")
            }
            .buttonStyle(.plain)
        }
    }

    private func featureCard(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Colors.accent)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: - Step 2: Connect

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect your server")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Pick a preset or enter your own endpoint.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            ScrollingContent {
            VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("Presets")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
                presetButton("Localhost", name: "Local Dev", url: "http://localhost:6333", env: "Development")
                presetButton("Qdrant Cloud", name: "Qdrant Cloud", url: "https://your-cluster.cloud.qdrant.io:6333", env: "Production")
                presetButton("Staging", name: "Staging", url: "http://qdrant.internal:6333", env: "Staging")
            }

            HStack(spacing: 10) {
                FormField(label: "Name", placeholder: "e.g. Local Dev", text: $appState.newServerName)
                FormEnvironmentPicker(selection: $appState.newServerEnvironment).frame(width: 150)
            }

            FormField(label: "Endpoint (REST)", placeholder: "http://localhost:6333", text: $appState.newServerURL, mono: true)
            InsecureHTTPNotice(urlString: appState.newServerURL, allowed: $appState.newServerAllowInsecure)
            FormField(label: "API key (optional)", placeholder: "Required for Qdrant Cloud or secured servers", text: $appState.newServerApiKey, mono: true, secure: true)

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Task { await appState.testConnection(urlString: appState.newServerURL, apiKey: appState.newServerApiKey, allowInsecureHTTP: appState.newServerAllowInsecure) }
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
            .padding(.bottom, 8)
            }

            HStack {
                Button {
                    withAnimation { appState.onboardingStep = 0 }
                } label: {
                    Text("← Back")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)

                Spacer()

                if appState.testConnectionSuccess == false {
                    Button {
                        saveAndContinue()
                    } label: {
                        Text("Save anyway")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }

                Button {
                    Task {
                        if appState.testConnectionSuccess != true {
                            await appState.testConnection(urlString: appState.newServerURL, apiKey: appState.newServerApiKey, allowInsecureHTTP: appState.newServerAllowInsecure)
                        }
                        if appState.testConnectionSuccess == true { saveAndContinue() }
                    }
                } label: {
                    PrimaryPillLabel(title: "Connect & continue  →")
                        .opacity(appState.newServerURL.isEmpty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(appState.newServerURL.isEmpty || appState.isTestingConnection)
            }
        }
        .onChange(of: appState.newServerURL) { _, _ in appState.resetTestResult() }
        .onChange(of: appState.newServerApiKey) { _, _ in appState.resetTestResult() }
        .onChange(of: appState.newServerAllowInsecure) { _, _ in appState.resetTestResult() }
    }

    private func saveAndContinue() {
        appState.addServer(
            name: appState.newServerName,
            urlString: appState.newServerURL,
            apiKey: appState.newServerApiKey,
            environmentTag: appState.newServerEnvironment,
            allowInsecureHTTP: appState.newServerAllowInsecure
        )
        withAnimation { appState.onboardingStep = 2 }
    }

    private func presetButton(_ title: String, name: String, url: String, env: String) -> some View {
        Button {
            appState.newServerName = name
            appState.newServerURL = url
            appState.newServerEnvironment = env
        } label: {
            PillLabel(text: title)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Connected

    private var connectedStep: some View {
        let online = appState.isHealthy
        let color: Color = online ? Theme.Colors.statusGreen : (appState.isUnauthorized ? Theme.Colors.statusYellow : Theme.Colors.statusGray)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: online ? "checkmark" : (appState.isUnauthorized ? "lock.fill" : "ellipsis"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(color)
                )

            Text(online ? "You're connected" : (appState.isUnauthorized ? "Saved, but locked" : "Saved"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, 16)

            Text(summaryLine)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 10) {
                tip("menubar.rectangle", "Find QdrantBar in the menu bar. The dot shows status: green, amber or gray.")
                tip("magnifyingglass", "Filter collections on the Collections tab, and open any of them in the Qdrant dashboard.")
                tip("plus.circle", "Add more servers any time from the Servers tab.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .padding(.top, 24)

            Spacer(minLength: 0)

            Button {
                appState.hasCompletedOnboarding = true
                OnboardingWindowManager.shared.close()
                Task { await appState.refreshAll() }
            } label: {
                PrimaryPillLabel(title: "Open QdrantBar")
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryLine: String {
        var parts = [appState.activeServer.name]
        switch appState.connection {
        case .online:
            if let version = appState.version { parts.append("v\(version.version)") }
            if let latency = appState.latencyMs { parts.append(String(format: "%.0f ms", latency)) }
            parts.append("\(appState.collections.count) collections")
        case .unauthorized:
            parts.append("needs an API key")
        case .offline:
            parts.append("checking…")
        }
        return parts.joined(separator: " · ")
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
