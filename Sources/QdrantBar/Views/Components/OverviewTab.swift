import SwiftUI
import QdrantBarCore

struct OverviewTab: View {
    @EnvironmentObject var appState: AppState

    private var parts: [SplitBar.Part] {
        appState.collections.filter { $0.pointsCount > 0 }.map { SplitBar.Part(id: $0.name, value: $0.pointsCount) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.isHealthy {
                healthy
            } else {
                Text(appState.isUnauthorized ? "Collections stay hidden until the server accepts your key." : "No data while the server is unreachable.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)
            }
        }
        .padding(.horizontal, Theme.Layout.gutter)
    }

    private var healthy: some View {
        VStack(alignment: .leading, spacing: 0) {
            label("Probe latency", trailing: appState.latencyMs.map { String(format: "%.0f ms", $0) })
            LatencySparkline(values: appState.latencyHistory)
                .frame(height: 64)
                .padding(.top, 8)

            label("Points by collection", trailing: "\(appState.collections.count) collections")
                .padding(.top, 18)
            if parts.isEmpty {
                Text("No points stored yet")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(.top, 8)
            } else {
                SplitBar(parts: parts)
                    .frame(height: 10)
                    .padding(.top, 8)
                legend
                    .padding(.top, 8)
            }

            HStack {
                stat("Vectors", Format.compact(appState.totalVectors))
                stat("Segments", "\(appState.totalSegments)")
                stat("Healthy", "\(appState.healthyCollectionsCount)/\(appState.collections.count)")
            }
            .padding(.top, 20)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Array(parts.prefix(3).enumerated()), id: \.element.id) { index, part in
                HStack(spacing: 5) {
                    Circle().fill(SplitBar.color(at: index)).frame(width: 6, height: 6)
                    Text(part.id)
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            if parts.count > 3 {
                Text("+\(parts.count - 3) more")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    private func label(_ text: String, trailing: String?) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Typography.statValue)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
