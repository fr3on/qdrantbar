import SwiftUI

struct DashboardTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppState.DashboardTab.allCases) { tab in
                let selected = appState.selectedTab == tab
                Button {
                    appState.selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selected ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selected ? Theme.Colors.pillBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, Theme.Layout.gutter)
    }
}
