import SwiftUI

/// Probe latency over the last few checks. Scales to its own min and max.
struct LatencySparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            if values.count < 2 {
                Text("Collecting samples…")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let low = values.min() ?? 0
                let high = max(values.max() ?? 1, low + 5)
                let step = geo.size.width / CGFloat(values.count - 1)
                let points = values.enumerated().map { index, value in
                    CGPoint(x: CGFloat(index) * step, y: geo.size.height * (1 - CGFloat((value - low) / (high - low))))
                }
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Theme.Colors.accent.opacity(0.35), Theme.Colors.accent.opacity(0)], startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

/// One stacked bar showing how points split across collections.
struct SplitBar: View {
    struct Part: Identifiable {
        let id: String
        let value: Int
    }

    let parts: [Part]
    static let palette: [Color] = [
        Theme.Colors.accent,
        Theme.Colors.accentSoft,
        Color(red: 0.294, green: 0.306, blue: 0.769),
        Color(red: 0.42, green: 0.44, blue: 0.85),
    ]

    static func color(at index: Int) -> Color { palette[index % palette.count] }

    var body: some View {
        let total = max(parts.map(\.value).reduce(0, +), 1)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Self.color(at: index))
                        .frame(width: max(4, (geo.size.width - CGFloat(parts.count) * 2) * CGFloat(part.value) / CGFloat(total)))
                }
            }
        }
    }
}
