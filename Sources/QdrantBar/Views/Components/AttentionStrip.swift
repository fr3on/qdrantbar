import SwiftUI
import QdrantBarCore

/// Appears only when something needs the user, and offers one clear action. One item at a time.
struct AttentionStrip: View {
    @EnvironmentObject var appState: AppState

    private enum Item {
        case offline
        case unauthorized
        case degraded(Int)
    }

    private var item: Item? {
        switch appState.connection {
        case .offline: return .offline
        case .unauthorized: return .unauthorized
        case .online:
            // Already on the Collections tab, the yellow dots say it; no need to point there.
            let count = appState.degradedCollectionsCount
            return count > 0 && appState.selectedTab != .collections ? .degraded(count) : nil
        }
    }

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.statusYellow)
                    Text("1 item needs attention")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    switch item {
                    case .offline: offlineBody
                    case .unauthorized: unauthorizedBody
                    case let .degraded(count): degradedBody(count)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Theme.Layout.gutter)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Theme.Colors.textPrimary)
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(Theme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var retryButton: some View {
        Button {
            Task { await appState.refreshAll() }
        } label: {
            Text("Retry")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var offlineBody: some View {
        if case .insecureConnection = appState.connectionError {
            insecureBody
        } else {
            plainOfflineBody
        }
    }

    /// A remote http:// server the user has not allowed. Explains why, and offers the way through.
    private var insecureBody: some View {
        Group {
            title("Insecure connection blocked")
            detail(appState.connectionError?.localizedDescription ?? "")
            HStack(spacing: 12) {
                Spacer()
                Button {
                    appState.navigateToManageServers()
                } label: {
                    Text("Servers")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                Button {
                    appState.setAllowInsecureHTTP(true)
                } label: {
                    PrimaryPillLabel(title: "Allow insecure HTTP")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var plainOfflineBody: some View {
        Group {
            title("Qdrant unreachable")
            detail("Cannot connect to \(appState.hostURLString). Check that the server is running and the URL is right.")
            HStack(spacing: 12) {
                Spacer()
                Button {
                    appState.navigateToManageServers()
                } label: {
                    Text("Servers")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    PrimaryPillLabel(title: "Retry")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var unauthorizedBody: some View {
        Group {
            title("Unauthorized")
            detail("Qdrant answered /healthz but rejected /collections. This server needs an API key.")

            SecureField("API key", text: $appState.apiKeyDraft)
                .textFieldStyle(.plain)
                .font(Theme.Typography.mono)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.Colors.pillBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onSubmit { submitKey() }

            HStack(spacing: 12) {
                Spacer()
                retryButton
                Button {
                    submitKey()
                } label: {
                    PrimaryPillLabel(title: "Save key")
                }
                .buttonStyle(.plain)
                .disabled(appState.apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func degradedBody(_ count: Int) -> some View {
        Group {
            title(count == 1 ? "1 collection is not green" : "\(count) collections are not green")
            detail("Yellow usually means an optimizer is running or replicas are catching up.")
            HStack {
                Spacer()
                Button {
                    appState.selectedTab = .collections
                } label: {
                    PrimaryPillLabel(title: "View collections")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func submitKey() {
        let key = appState.apiKeyDraft
        appState.apiKeyDraft = ""
        Task { await appState.saveApiKey(key) }
    }
}
