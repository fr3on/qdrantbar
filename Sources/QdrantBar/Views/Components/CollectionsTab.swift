import SwiftUI
import QdrantBarCore

/// Flat rows, no boxes. Names get the full row width.
struct CollectionsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            filterField
                .padding(.horizontal, Theme.Layout.gutter)

            if appState.collectionsWorstFirst.isEmpty {
                Text(appState.searchQuery.isEmpty ? (appState.isHealthy ? "No collections yet" : "Nothing to show") : "No matches")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.collectionsWorstFirst) { collection in
                        row(collection)
                        if collection.id != appState.collectionsWorstFirst.last?.id {
                            Rectangle()
                                .fill(Theme.Colors.border)
                                .frame(height: 1)
                                .padding(.leading, Theme.Layout.gutter + 17)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var filterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)
            TextField("Filter collections", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !appState.searchQuery.isEmpty {
                Button {
                    appState.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ collection: CollectionItem) -> some View {
        Button {
            appState.openCollection(collection.name)
        } label: {
            HStack(spacing: 10) {
                StatusDot(color: color(for: collection.status), size: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(collection.vectorDimensionsSummary)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(Format.count(collection.pointsCount))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(Theme.Colors.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, Theme.Layout.gutter)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.copyCurl(collection: collection)
            } label: {
                Label("Copy curl command", systemImage: "doc.on.doc")
            }
            Button {
                appState.copyText(collection.name)
            } label: {
                Label("Copy collection name", systemImage: "text.cursor")
            }
            Divider()
            Button {
                appState.openCollectionInDashboard(name: collection.name)
            } label: {
                Label("View in Dashboard", systemImage: "macwindow")
            }
        }
    }

    private func color(for status: CollectionStatus) -> Color {
        switch status {
        case .green: return Theme.Colors.statusGreen
        case .yellow: return Theme.Colors.statusYellow
        case .grey, .unknown: return Theme.Colors.statusGray
        }
    }
}
