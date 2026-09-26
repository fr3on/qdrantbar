import SwiftUI
import AppKit
import ServiceManagement
import QdrantBarCore

@MainActor
public final class AppState: ObservableObject {
    @Published public var servers: [ServerProfile] = [] {
        didSet {
            saveServers()
        }
    }

    @Published public var activeServerId: UUID {
        didSet {
            UserDefaults.standard.set(activeServerId.uuidString, forKey: "qdrant_active_server_id")
            Task { await handleActiveServerChanged() }
        }
    }

    @Published public var apiKey: String = ""
    /// Text typed into the "API key required" card. Cleared as soon as it is submitted.
    @Published public var apiKeyDraft: String = ""
    @Published public var connection: ConnectionState = .offline
    /// Why the last connection attempt failed, when it did. Lets the UI explain a blocked insecure server.
    @Published public var connectionError: QdrantClientError?

    /// Reachable and accepted by the server. `/healthz` needs no key, so it alone never counts.
    public var isHealthy: Bool { connection == .online }
    public var isUnauthorized: Bool { connection == .unauthorized }
    @Published public var version: QdrantVersion?
    @Published public var collections: [CollectionItem] = []
    @Published public var latencyMs: Double? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var searchQuery: String = ""

    public enum PopoverViewMode: Equatable {
        case dashboard
        case addServer
        case collectionDetail
        case settings
    }

    public enum DashboardTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case collections = "Collections"
        case servers = "Servers"

        public var id: String { rawValue }
    }

    @Published public var currentView: PopoverViewMode = .dashboard
    @Published public var selectedTab: DashboardTab = .overview
    @Published public var lastChecked: Date?
    /// True for inert snapshot states, where AppKit-backed controls (ScrollView) cannot be rendered to an image.
    public let isSnapshot: Bool
    /// Snapshot-only: shifts the detail screen up to show its lower half in a static image.
    public var snapshotScrollOffset: CGFloat = 0

    @Published public var collectionBundle: CollectionDetailBundle?
    /// Which copy action just ran ("json" or "curl"), so its button can say "Copied" for a moment.
    @Published public var copiedLabel: String?
    @Published public var onboardingStep: Int = 0
    @Published public var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "has_completed_onboarding")
        }
    }
    @Published public var copiedCollectionName: String? = nil

    public func navigateToDashboard() {
        withAnimation(.easeInOut(duration: 0.15)) {
            self.currentView = .dashboard
        }
    }

    /// Servers live in the dashboard's Servers tab, so this just returns there.
    public func navigateToManageServers() {
        withAnimation(.easeInOut(duration: 0.15)) {
            self.selectedTab = .servers
            self.currentView = .dashboard
        }
    }

    public func navigateToAddServer() {
        self.newServerName = ""
        self.newServerURL = "http://localhost:6333"
        self.newServerApiKey = ""
        self.newServerEnvironment = "Development"
        self.newServerAllowInsecure = false
        self.testConnectionResult = nil
        self.testConnectionSuccess = nil
        self.testConnectionNeedsKey = false
        withAnimation(.easeInOut(duration: 0.15)) {
            self.currentView = .addServer
        }
    }

    // Add server form fields
    @Published public var newServerName: String = ""
    @Published public var newServerURL: String = "http://localhost:6333"
    @Published public var newServerApiKey: String = ""
    @Published public var newServerEnvironment: String = "Development"
    @Published public var newServerAllowInsecure: Bool = false
    @Published public var isTestingConnection: Bool = false
    @Published public var testConnectionResult: String? = nil
    @Published public var testConnectionSuccess: Bool? = nil
    @Published public var testConnectionNeedsKey: Bool = false

    @Published public var settings: AppSettings {
        didSet {
            let clean = settings.normalized()
            if clean != settings {
                settings = clean
                return
            }
            if !isSnapshot { settings.save() }
            if oldValue.backgroundRefreshSeconds != settings.backgroundRefreshSeconds { startBackgroundHealthTimer() }
            if oldValue.openRefreshSeconds != settings.openRefreshSeconds, isPopoverOpen { startOpenRefreshLoop() }
        }
    }

    @Published public var isPopoverOpen: Bool = false {
        didSet {
            guard isPopoverOpen != oldValue else { return }
            if isPopoverOpen {
                startOpenRefreshLoop()
            } else {
                openRefreshTask?.cancel()
                openRefreshTask = nil
            }
        }
    }

    /// While the popover is on screen: refresh now, then every `openRefreshSeconds`.
    private func startOpenRefreshLoop() {
        openRefreshTask?.cancel()
        guard !isSnapshot else { return }
        openRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshAll()
                try? await Task.sleep(nanoseconds: UInt64(self.settings.openRefreshSeconds) * 1_000_000_000)
            }
        }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }

    @Published public var themeMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "qdrant_theme_mode")
            applyTheme()
        }
    }

    private var client: QdrantClient
    private var backgroundHealthTimer: Timer?
    private var openRefreshTask: Task<Void, Never>?
    /// Set while the toggle is being put back after a failed registration, so that does not retry.
    private var isRevertingLaunchAtLogin = false
    @Published public var launchAtLoginMessage: String?

    /// `startServices: false` builds an inert state (no network, timers or windows) for snapshots.
    public init(startServices: Bool = true) {
        self.isSnapshot = !startServices
        self.settings = startServices ? AppSettings.load() : AppSettings()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")

        let savedTheme = UserDefaults.standard.string(forKey: "qdrant_theme_mode") ?? AppThemeMode.system.rawValue
        self.themeMode = AppThemeMode(rawValue: savedTheme) ?? .system

        // Load saved servers or initialize default Localhost
        var loadedServers: [ServerProfile] = []
        if let data = UserDefaults.standard.data(forKey: "qdrant_saved_servers"),
           let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data),
           !decoded.isEmpty {
            loadedServers = decoded
        } else {
            loadedServers = [ServerProfile.defaultLocal]
        }
        self.servers = loadedServers

        // Determine active server ID
        let savedActiveIdString = UserDefaults.standard.string(forKey: "qdrant_active_server_id")
        let activeId = (savedActiveIdString != nil ? UUID(uuidString: savedActiveIdString!) : nil)
            ?? loadedServers.first?.id
            ?? UUID()
        self.activeServerId = activeId

        let activeProfile = loadedServers.first(where: { $0.id == activeId }) ?? ServerProfile.defaultLocal
        let initialURL = URL(string: activeProfile.urlString) ?? URL(string: "http://localhost:6333")!
        self.client = QdrantClient(baseURL: initialURL, allowInsecureHTTP: activeProfile.allowInsecureHTTP)

        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }

        self.applyTheme()

        guard startServices else { return }

        Task {
            if let savedKey = await KeychainManager.shared.getApiKey(for: activeProfile.id.uuidString) {
                self.apiKey = savedKey
                await self.client.updateApiKey(savedKey)
            }
            await self.refreshAll()
            self.startBackgroundHealthTimer()

            if !self.hasCompletedOnboarding {
                try? await Task.sleep(nanoseconds: 400_000_000)
                self.launchOnboardingWindow()
            }
        }
    }

    public func launchOnboardingWindow(step: Int = 0) {
        self.onboardingStep = step
        OnboardingWindowManager.shared.show(appState: self)
    }

    public var activeServer: ServerProfile {
        servers.first(where: { $0.id == activeServerId }) ?? (servers.first ?? ServerProfile.defaultLocal)
    }

    /// The active server is remote plain HTTP that the user allowed. Worth a permanent reminder in the UI.
    public var activeServerIsInsecure: Bool { activeServer.isInsecureRemote }

    /// Grants or revokes the plain-HTTP opt-in for the active server, then re-checks it.
    public func setAllowInsecureHTTP(_ allowed: Bool) {
        guard let index = servers.firstIndex(where: { $0.id == activeServerId }) else { return }
        servers[index].allowInsecureHTTP = allowed
        Task {
            await client.updateAllowInsecureHTTP(allowed)
            await refreshAll()
        }
    }

    public var hostURLString: String {
        activeServer.urlString
    }

    public var filteredCollections: [CollectionItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return collections
        }
        return collections.filter { $0.name.lowercased().contains(query) }
    }

    public var totalPoints: Int {
        collections.reduce(0) { $0 + $1.pointsCount }
    }

    public var totalVectors: Int {
        collections.reduce(0) { $0 + $1.vectorsCount }
    }

    public var totalIndexedVectors: Int {
        collections.reduce(0) { $0 + ($1.detail?.indexedVectorsCount ?? 0) }
    }

    public var totalSegments: Int {
        collections.reduce(0) { $0 + ($1.detail?.segmentsCount ?? 0) }
    }

    /// Collections needing a look come first, then the biggest ones.
    public var collectionsWorstFirst: [CollectionItem] {
        filteredCollections.sorted { lhs, rhs in
            let lhsBad = lhs.status != .green, rhsBad = rhs.status != .green
            if lhsBad != rhsBad { return lhsBad }
            return lhs.pointsCount > rhs.pointsCount
        }
    }

    public var healthyCollectionsCount: Int {
        collections.filter { $0.status == .green }.count
    }

    public var degradedCollectionsCount: Int {
        collections.filter { $0.status == .yellow || $0.status == .grey }.count
    }

    @Published public var latencyHistory: [Double] = []

    public var pointsDistribution: [CGFloat] {
        guard !collections.isEmpty, totalPoints > 0 else {
            return []
        }
        let maxCount = collections.map(\.pointsCount).max() ?? 1
        return collections.prefix(10).map { CGFloat($0.pointsCount) / CGFloat(max(1, maxCount)) }
    }

    public var latencySparklinePoints: [CGFloat] {
        guard latencyHistory.count > 1 else {
            return []
        }
        let maxLatency = latencyHistory.max() ?? 1.0
        let minLatency = latencyHistory.min() ?? 0.0
        let range = max(5.0, maxLatency - minLatency)
        return latencyHistory.map { CGFloat(($0 - minLatency) / range) }
    }

    public var primaryVectorConfigSummary: String {
        guard let firstWithVectors = collections.first(where: { $0.detail?.config?.params?.vectors != nil }) else {
            return "\(totalPoints) stored points"
        }
        let dims = firstWithVectors.vectorDimensionsSummary
        if collections.count <= 1 {
            return "\(dims) vectors"
        }
        return "\(dims) • \(collections.count) cols"
    }

    public var primaryVectorBadge: String {
        for col in collections {
            if let config = col.detail?.config?.params?.vectors {
                switch config {
                case let .single(params):
                    if let size = params.size {
                        return "\(size)D"
                    }
                case let .multiple(dict):
                    return "\(dict.count) VECS"
                }
            }
        }
        return "DENSE"
    }

    public var indexRatio: Double {
        guard totalVectors > 0 else { return 0.0 }
        return min(1.0, Double(totalIndexedVectors) / Double(totalVectors))
    }

    public func recordLatency(_ ms: Double) {
        self.lastChecked = Date()
        self.latencyMs = ms
        latencyHistory.append(ms)
        if latencyHistory.count > 16 {
            latencyHistory.removeFirst()
        }
    }

    public func applyTheme() {
        switch themeMode {
        case .system:
            NSApp?.appearance = nil
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        }
    }

    private func saveServers() {
        guard !isSnapshot else { return }
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: "qdrant_saved_servers")
        }
    }

    public func switchServer(to server: ServerProfile) {
        guard activeServerId != server.id else { return }
        self.activeServerId = server.id
    }

    public func handleActiveServerChanged() async {
        closeCollection()
        guard let url = URL(string: activeServer.urlString) else { return }
        await client.updateBaseURL(url)
        await client.updateAllowInsecureHTTP(activeServer.allowInsecureHTTP)
        let key = await KeychainManager.shared.getApiKey(for: activeServer.id.uuidString)
        self.apiKey = key ?? ""
        await client.updateApiKey(key)
        await refreshAll()
    }

    public func addServer(name: String, urlString: String, apiKey: String, environmentTag: String, allowInsecureHTTP: Bool = false) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let profile = ServerProfile(
            name: cleanName.isEmpty ? "Qdrant Server" : cleanName,
            urlString: cleanURL.isEmpty ? "http://localhost:6333" : cleanURL,
            environmentTag: environmentTag,
            // Only meaningful for remote plain http; never stored for a server that does not need it.
            allowInsecureHTTP: allowInsecureHTTP && ConnectionPolicy.requiresInsecureOptIn(cleanURL)
        )

        servers.append(profile)
        if !cleanKey.isEmpty {
            Task {
                try? await KeychainManager.shared.saveApiKey(cleanKey, for: profile.id.uuidString)
            }
        }

        switchServer(to: profile)
    }

    public func deleteServer(id: UUID) {
        guard servers.count > 1 else { return } // Keep at least one server
        servers.removeAll(where: { $0.id == id })
        Task {
            try? await KeychainManager.shared.deleteApiKey(for: id.uuidString)
        }
        if activeServerId == id, let first = servers.first {
            switchServer(to: first)
        }
    }

    /// Saves a new key for the active server and re-checks it. The key goes to the Keychain, never to defaults.
    public func saveApiKey(_ key: String) async {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await KeychainManager.shared.saveApiKey(clean, for: activeServer.id.uuidString)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        apiKey = clean
        await client.updateApiKey(clean)
        await refreshAll()
    }

    public func resetTestResult() {
        testConnectionResult = nil
        testConnectionSuccess = nil
        testConnectionNeedsKey = false
    }

    /// Reachable is not enough: `/healthz` and `/` need no key, so the key is only proven by `/collections`.
    public func testConnection(urlString: String, apiKey: String, allowInsecureHTTP: Bool = false) async {
        isTestingConnection = true
        resetTestResult()
        defer { isTestingConnection = false }

        let cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanURL), url.host != nil else {
            testConnectionResult = "Invalid server URL"
            testConnectionSuccess = false
            return
        }

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let testClient = QdrantClient(baseURL: url, apiKey: cleanKey.isEmpty ? nil : cleanKey, allowInsecureHTTP: allowInsecureHTTP)
        let start = DispatchTime.now()

        do {
            let health = try await testClient.checkHealth()
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
            guard health.isHealthy else {
                testConnectionResult = "Server reachable but reported an unhealthy status."
                testConnectionSuccess = false
                return
            }
            let collections = try await testClient.fetchCollections()
            let version = (try? await testClient.fetchVersion())?.version ?? health.version ?? "unknown"
            testConnectionResult = "Connected · v\(version) · \(String(format: "%.0f ms", ms)) · \(collections.count) collections"
            testConnectionSuccess = true
        } catch QdrantClientError.unauthorized {
            testConnectionResult = cleanKey.isEmpty ? "Server reachable, but it needs an API key" : "Server reachable, but the key was rejected"
            testConnectionSuccess = false
            testConnectionNeedsKey = true
        } catch {
            // insecureConnection reads as plain advice: use https, a tunnel, or allow it for this server.
            testConnectionResult = error.localizedDescription
            testConnectionSuccess = false
        }
    }

    private func startBackgroundHealthTimer() {
        backgroundHealthTimer?.invalidate()
        backgroundHealthTimer = nil
        guard !isSnapshot, settings.backgroundRefreshSeconds > 0 else { return }
        backgroundHealthTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.backgroundRefreshSeconds), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if !self.isPopoverOpen {
                    await self.checkHealthOnly()
                }
            }
        }
    }

    public func checkHealthOnly() async {
        do {
            let start = DispatchTime.now()
            let health = try await client.checkHealth()
            let end = DispatchTime.now()
            let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
            self.recordLatency(ms)
            // /healthz cannot see auth problems, so keep what the last full refresh learned.
            if !health.isHealthy {
                self.connection = .offline
            } else if self.connection == .offline {
                self.connection = .online
                self.connectionError = nil
            }
        } catch {
            self.lastChecked = Date()
            self.connection = .offline
            self.connectionError = error as? QdrantClientError
            self.latencyMs = nil
        }
    }

    public func refreshAll() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let startTime = DispatchTime.now()
        do {
            let health = try await client.checkHealth()
            let endTime = DispatchTime.now()
            let ms = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
            self.recordLatency(ms)
            guard health.isHealthy else {
                markOffline(nil)
                return
            }
            connectionError = nil
        } catch {
            markOffline(error as? QdrantClientError)
            return
        }

        // Fetch Version & Collections. A rejected key is a state of its own, not "healthy".
        do {
            async let versionTask = client.fetchVersion()
            async let collectionsTask = client.fetchCollections()

            let (ver, summaries) = try await (versionTask, collectionsTask)
            self.version = ver
            self.connection = .online

            var items = summaries.map { CollectionItem(name: $0.name, isLoading: true) }
            self.collections = items

            await withTaskGroup(of: (String, CollectionDetail?).self) { group in
                for summary in summaries {
                    group.addTask {
                        let detail = try? await self.client.fetchCollectionDetails(name: summary.name)
                        return (summary.name, detail)
                    }
                }

                for await (name, detail) in group {
                    if let index = items.firstIndex(where: { $0.name == name }) {
                        items[index].detail = detail
                        items[index].isLoading = false
                    }
                }
            }

            self.collections = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if currentView == .collectionDetail, let name = collectionBundle?.name {
                await loadCollection(name)
            }
        } catch QdrantClientError.unauthorized {
            self.connection = .unauthorized
            self.collections = []
            self.version = nil
            self.errorMessage = QdrantClientError.unauthorized.localizedDescription
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Drops what the last good refresh showed so an unreachable server never displays stale numbers.
    private func markOffline(_ error: QdrantClientError?) {
        lastChecked = Date()
        connection = .offline
        connectionError = error
        latencyMs = nil
        collections = []
        version = nil
    }

    // MARK: Collection detail

    public func openCollection(_ name: String) {
        collectionBundle = CollectionDetailBundle(name: name, isLoading: true)
        withAnimation(.easeInOut(duration: 0.15)) {
            currentView = .collectionDetail
        }
        Task { await loadCollection(name) }
    }

    public func closeCollection() {
        collectionBundle = nil
        if currentView == .collectionDetail {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentView = .dashboard
            }
        }
    }

    private static func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// The main call decides success; aliases, snapshots and optimizations may fail on their own
    /// (permissions, older servers) and are then shown as unavailable instead of empty.
    public func loadCollection(_ name: String) async {
        if collectionBundle?.name == name { collectionBundle?.isLoading = true }
        let client = self.client

        async let detailTask = Self.capture { try await client.fetchCollectionDetails(name: name) }
        async let aliasesTask = try? await client.fetchAliases(collection: name)
        async let snapshotsTask = try? await client.fetchSnapshots(collection: name)
        async let optimizationsTask = try? await client.fetchOptimizations(collection: name)
        async let jsonTask = try? await client.fetchCollectionJSON(name: name)
        let (detail, aliases, snapshots, optimizations, json) =
            await (detailTask, aliasesTask, snapshotsTask, optimizationsTask, jsonTask)

        // The user may have gone back, or opened another collection, while this was loading.
        guard collectionBundle?.name == name else { return }
        var bundle = CollectionDetailBundle(name: name)
        switch detail {
        case let .success(value):
            bundle.detail = value
        case let .failure(error):
            if case QdrantClientError.unauthorized = error { connection = .unauthorized }
            bundle.errorMessage = error.localizedDescription
        }
        bundle.aliases = aliases
        bundle.snapshots = snapshots
        bundle.optimizations = optimizations
        bundle.rawJSON = json
        collectionBundle = bundle
    }

    public func copyCollectionJSON() {
        guard let json = collectionBundle?.rawJSON else { return }
        copyText(json)
        flashCopied("json")
    }

    private func flashCopied(_ label: String) {
        copiedLabel = label
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedLabel == label { copiedLabel = nil }
        }
    }

    public func openDashboard() {
        let base = hostURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let url = URL(string: "\(base)/dashboard") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openCollectionInDashboard(name: String) {
        let base = hostURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        if let url = URL(string: "\(base)/dashboard#/collections/\(encodedName)") {
            NSWorkspace.shared.open(url)
        }
    }

    public func copyCurl(collection: CollectionItem) {
        copyCurl(name: collection.name)
    }

    public func copyCurl(name: String) {
        let command = CurlSnippet.collection(baseURL: hostURLString, name: name, apiKey: apiKey)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        flashCopied("curl")
    }

    public func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Registers or removes the login item. Skips the call when the system already agrees, so merely
    /// starting the app never re-registers it, and puts the switch back if the system refuses.
    private func setLaunchAtLogin(_ enabled: Bool) {
        guard !isRevertingLaunchAtLogin, !isSnapshot else { return }
        let status = SMAppService.mainApp.status
        let isOn = status == .enabled || status == .requiresApproval
        guard enabled != isOn else {
            launchAtLoginMessage = status == .requiresApproval ? "Approve QdrantBar in System Settings > Login Items." : nil
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginMessage = SMAppService.mainApp.status == .requiresApproval ? "Approve QdrantBar in System Settings > Login Items." : nil
        } catch {
            launchAtLoginMessage = "Couldn't change Launch at login: \(error.localizedDescription)"
            isRevertingLaunchAtLogin = true
            launchAtLogin = !enabled
            isRevertingLaunchAtLogin = false
        }
    }

    // MARK: Settings navigation and menu bar

    public func openSettings() {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentView = .settings
        }
    }

    public func closeSettings() {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentView = .dashboard
        }
    }

    /// What the menu bar item shows right now.
    public var menuBarDisplay: MenuBarDisplay {
        MenuBarDisplay.make(
            MenuBarDisplay.Input(
                connection: connection,
                hasDegradedCollections: degradedCollectionsCount > 0,
                totalPoints: totalPoints,
                latencyMs: latencyMs,
                collectionCount: collections.count,
                serverName: activeServer.name
            ),
            settings: settings
        )
    }
}
