import SwiftUI
import QdrantBarCore

/// Labeled text field used by onboarding and Add Server. In snapshots AppKit-backed fields cannot be
/// rendered to an image, so a plain `Text` stands in for them.
struct FormField: View {
    @EnvironmentObject var appState: AppState

    let label: String
    let placeholder: String
    @Binding var text: String
    var mono = false
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
            FormFieldChrome {
                if appState.isSnapshot {
                    Text(text.isEmpty ? placeholder : (secure ? String(repeating: "•", count: 24) : text))
                        .foregroundColor(text.isEmpty ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                } else if secure {
                    SecureField(placeholder, text: $text).textFieldStyle(.plain)
                } else {
                    TextField(placeholder, text: $text).textFieldStyle(.plain)
                }
            }
            .font(.system(size: 12.5, design: mono ? .monospaced : .default))
        }
    }
}

struct FormFieldChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border))
    }
}

struct FormEnvironmentPicker: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: String

    private let environments = ["Development", "Staging", "Production", "Testing"]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Environment")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
            if appState.isSnapshot {
                FormFieldChrome { Text(selection + " ⌄").foregroundColor(Theme.Colors.textPrimary) }
                    .font(.system(size: 12.5))
            } else {
                Picker("", selection: $selection) {
                    ForEach(environments, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A switch drawn by hand so it looks the same everywhere, including in image snapshots.
struct SwitchControl: View {
    @Binding var isOn: Bool
    /// Amber where a switch weakens security (insecure HTTP), the brand accent everywhere else.
    var tint: Color = Theme.Colors.statusYellow
    var accessibilityName = "Allow insecure HTTP"

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? tint : Theme.Colors.pillBackground)
                .frame(width: 32, height: 18)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(Color.white).frame(width: 14, height: 14).padding(2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Shown only for a remote `http://` URL. Off by default: the connection is refused until the user opts in.
struct InsecureHTTPNotice: View {
    let urlString: String
    @Binding var allowed: Bool

    var body: some View {
        if ConnectionPolicy.requiresInsecureOptIn(urlString) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.statusYellow)
                    Text("Plain HTTP to a remote server")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                Text("macOS blocks this by default because nothing is encrypted: your API key and data can be read on the way. Use https or an SSH tunnel if you can. Allow it only on a network you trust, such as a LAN or VPN.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    SwitchControl(isOn: $allowed)
                    Text("Allow insecure HTTP for this server")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.statusYellow.opacity(0.35)))
        }
    }
}

/// Scrolls in the app. Image rendering cannot draw ScrollView, so snapshots get a clipped stack that can
/// be shifted with `snapshotScrollOffset` to show a lower part of a long form.
struct ScrollingContent<Content: View>: View {
    @EnvironmentObject var appState: AppState
    @ViewBuilder let content: Content

    var body: some View {
        if appState.isSnapshot {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    content.offset(y: -appState.snapshotScrollOffset)
                }
                .clipped()
        } else {
            ScrollView(.vertical, showsIndicators: false) { content }
        }
    }
}
