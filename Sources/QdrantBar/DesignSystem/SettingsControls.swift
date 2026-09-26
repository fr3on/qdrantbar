import SwiftUI

/// A titled block of settings rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.Layout.gutter)
                .padding(.bottom, 2)
            content
        }
        .padding(.top, 16)
    }
}

/// A row with a title, optional detail line, and a control on the right.
struct SettingRow<Control: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.vertical, 7)
    }
}

/// A pop-up choice. The menu is AppKit-backed and cannot be rendered to an image, so snapshots show a static pill.
struct SelectPill<Value: Hashable>: View {
    @EnvironmentObject var appState: AppState

    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    private var currentTitle: String {
        options.first { $0.value == selection }?.title ?? ""
    }

    private var pill: some View {
        HStack(spacing: 4) {
            Text(currentTitle)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.Colors.textSecondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    var body: some View {
        if appState.isSnapshot {
            pill
        } else {
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button {
                        selection = options[index].value
                    } label: {
                        if options[index].value == selection {
                            Label(options[index].title, systemImage: "checkmark")
                        } else {
                            Text(options[index].title)
                        }
                    }
                }
            } label: {
                pill
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
