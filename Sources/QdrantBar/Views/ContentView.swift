import SwiftUI
import QdrantBarCore

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentView {
            case .dashboard:
                dashboardView
            case .collectionDetail:
                CollectionDetailView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            case .settings:
                SettingsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            case .addServer:
                AddServerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .frame(width: Theme.Layout.popoverWidth, height: Theme.Layout.popoverHeight)
        .background(Theme.Colors.background)
        .onAppear {
            appState.isPopoverOpen = true
        }
        .onDisappear {
            appState.isPopoverOpen = false
        }
        .preferredColorScheme(appState.themeMode == .system ? nil : (appState.themeMode == .dark ? .dark : .light))
    }

    private var dashboardView: some View {
        VStack(spacing: 0) {
            PopoverHeader()
            HeroView()
            DashboardTabBar()
            AttentionStrip()
                .padding(.top, 14)

            if appState.isSnapshot {
                tabContent
                    .padding(.top, 14)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    tabContent
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                }
            }

            PopoverFooter()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
        case .overview: OverviewTab()
        case .collections: CollectionsTab()
        case .servers: ServersTab()
        }
    }
}
