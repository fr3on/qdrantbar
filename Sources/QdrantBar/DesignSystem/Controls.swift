import SwiftUI

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: 3)
    }
}

struct PillLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(Theme.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.Colors.pillBackground)
            .clipShape(Capsule())
    }
}

/// Filled accent capsule. Use for the one primary action in a view.
struct PrimaryPillLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.Colors.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.Colors.accent)
            .clipShape(Capsule())
    }
}

/// Quiet capsule for secondary actions.
struct QuietPillLabel: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            }
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Theme.Colors.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.pillBackground)
        .clipShape(Capsule())
    }
}
