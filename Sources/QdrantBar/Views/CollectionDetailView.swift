import SwiftUI
import QdrantBarCore

/// Read-only detail for one collection. Anything that changes state stays in the Qdrant dashboard.
struct CollectionDetailView: View {
    @EnvironmentObject var appState: AppState

    private var bundle: CollectionDetailBundle? { appState.collectionBundle }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let bundle {
                if bundle.detail != nil {
                    scrolling {
                        sections(bundle)
                    }
                } else if let message = bundle.errorMessage {
                    failure(message)
                } else {
                    VStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading…")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Spacer()
            }

            PopoverFooter()
        }
    }

    /// Image rendering cannot draw ScrollView, so snapshots show a plain clipped stack shifted by an offset.
    @ViewBuilder
    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if appState.isSnapshot {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    content().offset(y: -appState.snapshotScrollOffset)
                }
                .clipped()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                content().padding(.bottom, 12)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                appState.closeCollection()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Collections").font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundColor(Theme.Colors.textMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                StatusDot(color: statusColor)
                Text(bundle?.name ?? "")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var statusColor: Color {
        switch bundle?.status ?? .unknown {
        case .green: return Theme.Colors.statusGreen
        case .yellow: return Theme.Colors.statusYellow
        case .grey, .unknown: return Theme.Colors.statusGray
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func sections(_ bundle: CollectionDetailBundle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            summary(bundle)
            if let attention = bundle.attention { attentionCard(attention) }
            vectors(bundle)
            storage(bundle)
            payloadIndexes(bundle)
            aliases(bundle)
            snapshots(bundle)
            actions(bundle)
        }
    }

    private func section<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .padding(.horizontal, Theme.Layout.gutter)
            content()
        }
        .padding(.top, 18)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(Theme.Colors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Layout.gutter)
    }

    // MARK: Summary

    private func summary(_ bundle: CollectionDetailBundle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.points(bundle.pointsCount))
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(bundle.pointsCount == 1 ? "point" : "points")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
                optimizerPill(bundle)
            }

            indexingBlock(bundle)

            HStack {
                Text("\(bundle.segmentsCount) segments")
                Spacer()
                Text("Update queue: \(Format.count(bundle.updateQueueLength)) pending")
            }
            .font(.system(size: 11))
            .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(.horizontal, Theme.Layout.gutter)
    }

    private func optimizerPill(_ bundle: CollectionDetailBundle) -> some View {
        let text: String
        let color: Color
        if bundle.optimizerError != nil {
            text = "optimizer error"; color = Theme.Colors.statusRed
        } else if bundle.isOptimizing {
            text = "optimizing"; color = Theme.Colors.statusYellow
        } else {
            text = "optimizer ok"; color = Theme.Colors.textSecondary
        }
        return Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.Colors.pillBackground)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func indexingBlock(_ bundle: CollectionDetailBundle) -> some View {
        switch bundle.indexing {
        case .empty:
            note("No points yet.").padding(.horizontal, -Theme.Layout.gutter)
        case let .exactScan(threshold):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Index").font(.system(size: 11.5, weight: .medium)).foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                    Text("Exact scan").font(.system(size: 11.5, weight: .medium)).foregroundColor(Theme.Colors.textSecondary)
                }
                Text(threshold != nil
                     ? "Below the indexing threshold, so searches check every point. Zero indexed vectors is normal here."
                     : "No HNSW index built yet, so searches check every point.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .building(fraction):
            meter(label: "Indexing", fraction: fraction, color: Theme.Colors.statusYellow)
        case .indexed:
            meter(label: "Indexed", fraction: 1, color: Theme.Colors.accent)
        }
    }

    private func meter(label: String, fraction: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.system(size: 11.5, weight: .medium)).foregroundColor(Theme.Colors.textMuted)
                Spacer()
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                    .foregroundColor(fraction < 1 ? Theme.Colors.statusYellow : Theme.Colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.pillBackground)
                    Capsule().fill(color).frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
    }

    private func attentionCard(_ attention: CollectionAttention) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: attention.isError ? "exclamationmark.octagon.fill" : "info.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(attention.isError ? Theme.Colors.statusRed : Theme.Colors.statusYellow)
            VStack(alignment: .leading, spacing: 3) {
                Text(attention.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(attention.body)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 14)
    }

    // MARK: Vectors, storage, payload indexes

    private func vectors(_ bundle: CollectionDetailBundle) -> some View {
        let rows = bundle.vectorRows
        return section("Vectors", trailing: rows.isEmpty ? nil : "\(rows.count)") {
            if rows.isEmpty {
                note("No vector configuration reported.")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                if !row.notes.isEmpty {
                                    Text(row.notes)
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(row.spec)
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, Theme.Layout.gutter)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func storage(_ bundle: CollectionDetailBundle) -> some View {
        section("Storage & sharding") {
            VStack(spacing: 0) {
                ForEach(bundle.storageRows) { row in
                    HStack {
                        Text(row.label).font(.system(size: 12)).foregroundColor(Theme.Colors.textMuted)
                        Spacer()
                        Text(row.value).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, Theme.Layout.gutter)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func payloadIndexes(_ bundle: CollectionDetailBundle) -> some View {
        let rows = bundle.payloadIndexRows
        return section("Payload indexes", trailing: rows.isEmpty ? nil : "\(rows.count)") {
            if rows.isEmpty {
                note("No payload indexes. Filters on payload fields scan every point.")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Text(row.field)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            PillLabel(text: row.type)
                            Spacer(minLength: 6)
                            if let points = row.points {
                                Text(Format.compact(points))
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, Theme.Layout.gutter)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
    }

    // MARK: Aliases, snapshots

    private func aliases(_ bundle: CollectionDetailBundle) -> some View {
        section("Aliases") {
            if let aliases = bundle.aliases {
                if aliases.isEmpty {
                    note("No aliases")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                        ForEach(aliases) { PillLabel(text: $0.aliasName) }
                    }
                    .padding(.horizontal, Theme.Layout.gutter)
                }
            } else {
                note("Couldn't load aliases.")
            }
        }
    }

    private func snapshots(_ bundle: CollectionDetailBundle) -> some View {
        let shown = Array(bundle.sortedSnapshots.prefix(3))
        let extra = (bundle.snapshots?.count ?? 0) - shown.count
        return section("Snapshots", trailing: bundle.snapshots == nil ? nil : bundle.snapshotSummary) {
            if bundle.snapshots == nil {
                note("Couldn't load snapshots.")
            } else {
                VStack(spacing: 0) {
                    ForEach(shown) { snapshot in
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox").font(.system(size: 11)).foregroundColor(Theme.Colors.textMuted)
                            Text(snapshot.name)
                                .font(.system(size: 11.5))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 6)
                            Text(snapshot.createdAt.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "unknown")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMuted)
                            Text(ByteSize.string(snapshot.size))
                                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, Theme.Layout.gutter)
                        .padding(.vertical, 5)
                    }
                    if extra > 0 {
                        Text("+\(extra) older")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Layout.gutter)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func actions(_ bundle: CollectionDetailBundle) -> some View {
        HStack(spacing: 8) {
            Button {
                appState.openCollectionInDashboard(name: bundle.name)
            } label: {
                QuietPillLabel(title: "Dashboard", icon: "arrow.up.right")
            }
            .buttonStyle(.plain)

            Button {
                appState.copyCollectionJSON()
            } label: {
                QuietPillLabel(title: appState.copiedLabel == "json" ? "Copied" : "Copy JSON", icon: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .disabled(bundle.rawJSON == nil)

            Button {
                appState.copyCurl(name: bundle.name)
            } label: {
                QuietPillLabel(title: appState.copiedLabel == "curl" ? "Copied" : "curl")
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, Theme.Layout.gutter)
        .padding(.top, 20)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(Theme.Colors.statusYellow)
            Text("Couldn't load this collection")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let name = bundle?.name {
                Button {
                    Task { await appState.loadCollection(name) }
                } label: {
                    PrimaryPillLabel(title: "Retry")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
