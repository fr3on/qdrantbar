#if DEBUG
import AppKit
import SwiftUI
import QdrantBarCore

/// `QdrantBar --snapshot out.png` renders the popover in several states with fixture data, then exits.
/// It never touches the network, the Keychain or saved servers.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), args.indices.contains(flag + 1) else { return }
        _ = NSApplication.shared

        let size = CGSize(width: Theme.Layout.popoverWidth, height: Theme.Layout.popoverHeight)
        func panel(_ title: String, _ state: AppState) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                ContentView()
                    .environmentObject(state)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }

        let board = VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 28) {
                panel("Online · Overview", make(.online, tab: .overview))
                panel("Online · Collections", make(.online, tab: .collections))
                panel("Degraded · Collections", make(.online, tab: .collections, degraded: true))
            }
            HStack(alignment: .top, spacing: 28) {
                panel("Unauthorized", make(.unauthorized, tab: .overview))
                panel("Offline", make(.offline, tab: .overview))
                panel("Servers", make(.online, tab: .servers))
            }
        }
        .padding(36)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))
        .environment(\.colorScheme, .dark)

        let path = args[flag + 1]
        write(board, to: path)

        func window(_ title: String, _ state: AppState) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                OnboardingWindowView()
                    .environmentObject(state)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 8) {
                            ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                                Circle().fill($0).frame(width: 12, height: 12)
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    }
            }
        }

        let welcome = make(.offline, tab: .overview); welcome.onboardingStep = 0
        let connect = make(.offline, tab: .overview)
        connect.onboardingStep = 1
        connect.newServerName = "Local Dev"
        connect.newServerURL = "http://127.0.0.1:6333"
        connect.newServerApiKey = "secret"
        connect.testConnectionResult = "Server reachable, but the key was rejected"
        connect.testConnectionSuccess = false
        connect.testConnectionNeedsKey = true
        let done = make(.online, tab: .overview); done.onboardingStep = 2

        let onboarding = HStack(alignment: .top, spacing: 28) {
            window("1 · Welcome", welcome)
            window("2 · Connect (key rejected)", connect)
            window("3 · Connected", done)
        }
        .padding(36)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))
        .environment(\.colorScheme, .dark)
        write(onboarding, to: path.replacingOccurrences(of: ".png", with: "-onboarding.png"))

        let big = detailState(bigBundle())
        let bigScrolled = detailState(bigBundle())
        bigScrolled.snapshotScrollOffset = 330
        let detailBoard = HStack(alignment: .top, spacing: 28) {
            panel("Detail · large, healthy", big)
            panel("Detail · same, scrolled", bigScrolled)
            panel("Detail · yellow, indexing", detailState(busyBundle()))
            panel("Detail · small, exact scan", detailState(smallBundle()))
        }
        .padding(36)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))
        .environment(\.colorScheme, .dark)
        write(detailBoard, to: path.replacingOccurrences(of: ".png", with: "-detail.png"))

        // Plain-HTTP handling: blocked, allowed, explained in the strip, and reminded in the UI.
        func insecureServer(_ state: AppState, allowed: Bool) {
            state.servers = [
                ServerProfile(id: state.activeServerId, name: "Office Qdrant", urlString: "http://10.0.0.5:6333", environmentTag: "Production", allowInsecureHTTP: allowed),
                ServerProfile(name: "Localhost", urlString: "http://localhost:6333"),
            ]
        }
        func addServerState(allowed: Bool) -> AppState {
            let state = make(.offline, tab: .overview)
            state.currentView = .addServer
            state.newServerName = "Office Qdrant"
            state.newServerURL = "http://15.188.111.114:6333"
            state.newServerApiKey = "secret"
            state.newServerEnvironment = "Production"
            state.newServerAllowInsecure = allowed
            if allowed {
                state.testConnectionResult = "Connected · v1.19.1 · 61 ms · 3 collections"
                state.testConnectionSuccess = true
            } else {
                state.testConnectionResult = QdrantClientError.insecureConnection(host: "15.188.111.114").errorDescription
                state.testConnectionSuccess = false
            }
            return state
        }
        let blockedAdd = addServerState(allowed: false)
        blockedAdd.snapshotScrollOffset = 250
        let blocked = make(.offline, tab: .overview)
        insecureServer(blocked, allowed: false)
        blocked.connectionError = .insecureConnection(host: "10.0.0.5")
        let reminded = make(.online, tab: .servers)
        insecureServer(reminded, allowed: true)
        let onboardingInsecure = make(.offline, tab: .overview)
        onboardingInsecure.onboardingStep = 1
        onboardingInsecure.newServerName = "Office Qdrant"
        onboardingInsecure.newServerURL = "http://10.0.0.5:6333"
        onboardingInsecure.newServerApiKey = "secret"
        onboardingInsecure.testConnectionResult = QdrantClientError.insecureConnection(host: "10.0.0.5").errorDescription
        onboardingInsecure.testConnectionSuccess = false

        let onboardingScrolled = make(.offline, tab: .overview)
        onboardingScrolled.onboardingStep = 1
        onboardingScrolled.newServerName = onboardingInsecure.newServerName
        onboardingScrolled.newServerURL = onboardingInsecure.newServerURL
        onboardingScrolled.newServerApiKey = "secret"
        onboardingScrolled.testConnectionResult = onboardingInsecure.testConnectionResult
        onboardingScrolled.testConnectionSuccess = false
        onboardingScrolled.snapshotScrollOffset = 200

        let insecureBoard = VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 28) {
                panel("Add server · blocked until allowed (scrolled)", blockedAdd)
                panel("Add server · allowed", addServerState(allowed: true))
                panel("Offline strip · insecure blocked", blocked)
                panel("Servers · insecure marked", reminded)
            }
            HStack(alignment: .top, spacing: 28) {
                window("Onboarding · connect, insecure URL (top)", onboardingInsecure)
                window("Onboarding · same, scrolled", onboardingScrolled)
            }
        }
        .padding(36)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))
        .environment(\.colorScheme, .dark)
        write(insecureBoard, to: path.replacingOccurrences(of: ".png", with: "-insecure.png"))

        // Settings, and the real menu bar renderer on dark and light bars.
        let settingsTop = make(.online, tab: .overview)
        settingsTop.currentView = .settings
        let settingsBottom = make(.online, tab: .overview)
        settingsBottom.currentView = .settings
        settingsBottom.snapshotScrollOffset = 300

        func strip(_ display: MenuBarDisplay, dark: Bool) -> NSImage {
            let item = MenuBarImage.make(display)
            let size = NSSize(width: item.size.width + 28, height: 30)
            return NSImage(size: size, flipped: false) { rect in
                let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                appearance.performAsCurrentDrawingAppearance {
                    (dark ? NSColor(white: 0.11, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
                    item.draw(in: NSRect(x: 14, y: (rect.height - item.size.height) / 2, width: item.size.width, height: item.size.height))
                }
                return true
            }
        }
        let inputs: [(String, MenuBarDisplay.Input, AppSettings)] = [
            ("Icon only", .init(connection: .online, totalPoints: 3300, latencyMs: 44, collectionCount: 3), AppSettings(menuBarStat: .none)),
            ("Points (default)", .init(connection: .online, totalPoints: 3300, latencyMs: 44, collectionCount: 3), AppSettings()),
            ("Points, large", .init(connection: .online, totalPoints: 1_714_998, latencyMs: 44, collectionCount: 3), AppSettings()),
            ("Latency", .init(connection: .online, totalPoints: 3300, latencyMs: 44, collectionCount: 3), AppSettings(menuBarStat: .latency)),
            ("Collections", .init(connection: .online, totalPoints: 3300, latencyMs: 44, collectionCount: 3), AppSettings(menuBarStat: .collections)),
            ("Degraded", .init(connection: .online, hasDegradedCollections: true, totalPoints: 3300, latencyMs: 44, collectionCount: 3), AppSettings()),
            ("Needs key", .init(connection: .unauthorized), AppSettings()),
            ("Offline", .init(connection: .offline), AppSettings()),
            ("Offline, text on", .init(connection: .offline), AppSettings(hideStatWhenOffline: false)),
        ]
        let barBoard = VStack(alignment: .leading, spacing: 16) {
            Text("Menu bar item, drawn by MenuBarImage").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
            ForEach(inputs.indices, id: \.self) { index in
                let display = MenuBarDisplay.make(inputs[index].1, settings: inputs[index].2)
                HStack(spacing: 18) {
                    Text(inputs[index].0).font(.system(size: 12)).foregroundColor(.white.opacity(0.7)).frame(width: 130, alignment: .leading)
                    Image(nsImage: strip(display, dark: true))
                    Image(nsImage: strip(display, dark: false))
                }
            }
        }
        .padding(30)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))

        let settingsBoard = HStack(alignment: .top, spacing: 28) {
            panel("Settings · top", settingsTop)
            panel("Settings · scrolled", settingsBottom)
            barBoard
        }
        .padding(36)
        .background(Color(red: 0.055, green: 0.059, blue: 0.07))
        .environment(\.colorScheme, .dark)
        write(settingsBoard, to: path.replacingOccurrences(of: ".png", with: "-settings.png"))
        exit(0)
    }

    private static func write<V: View>(_ view: V, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:])
        else {
            print("snapshot failed: \(path)")
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }

    private static func detailState(_ bundle: CollectionDetailBundle) -> AppState {
        let state = make(.online, tab: .collections)
        state.currentView = .collectionDetail
        state.collectionBundle = bundle
        return state
    }

    private static func bigBundle() -> CollectionDetailBundle {
        let detail = CollectionDetail(
            status: .green, optimizerStatus: "ok", indexedVectorsCount: 3_432_219, pointsCount: 1_714_998, segmentsCount: 8,
            config: CollectionConfig(
                params: CollectionParams(
                    vectors: .multiple(["dense": VectorParams(size: 1024, distance: .cosine, onDisk: true)]),
                    sparseVectors: ["sparse": SparseVectorParams()],
                    shardNumber: 1, replicationFactor: 1, writeConsistencyFactor: 1, onDiskPayload: true),
                hnswConfig: HnswConfig(m: 16, efConstruct: 100)),
            payloadSchema: [
                "year": PayloadIndexInfo(dataType: "integer", points: 1_714_998),
                "canonical_id": PayloadIndexInfo(dataType: "keyword", points: 1_714_998),
                "doc_type": PayloadIndexInfo(dataType: "keyword", points: 1_714_998),
                "status": PayloadIndexInfo(dataType: "keyword", points: 1_680_000),
            ],
            updateQueue: UpdateQueue(length: 0))
        return CollectionDetailBundle(
            name: "articles_cohere_v1", detail: detail, aliases: [],
            snapshots: [SnapshotDescription(name: "articles_cohere_v1-6427506419721257-2026-09-06-19-32-24.snapshot", creationTime: "2026-09-06T19:32:24", size: 10_951_393_280)],
            optimizations: OptimizationsInfo(summary: OptimizationsSummary(queuedOptimizations: 0, idleSegments: 8), running: []),
            rawJSON: "{}")
    }

    private static func busyBundle() -> CollectionDetailBundle {
        let detail = CollectionDetail(
            status: .yellow, optimizerStatus: "ok", indexedVectorsCount: 29_900, pointsCount: 48_210, segmentsCount: 12,
            config: CollectionConfig(
                params: CollectionParams(vectors: .single(VectorParams(size: 128, distance: .dot)), shardNumber: 1, replicationFactor: 1, writeConsistencyFactor: 1, onDiskPayload: false),
                hnswConfig: HnswConfig(m: 16, efConstruct: 100)),
            updateQueue: UpdateQueue(length: 1940))
        return CollectionDetailBundle(
            name: "support_tickets", detail: detail, aliases: [AliasDescription(aliasName: "tickets_live")], snapshots: [],
            optimizations: OptimizationsInfo(summary: OptimizationsSummary(queuedOptimizations: 1, queuedSegments: 3), running: [RunningOptimization()]),
            rawJSON: "{}")
    }

    private static func smallBundle() -> CollectionDetailBundle {
        let detail = CollectionDetail(
            status: .green, optimizerStatus: "ok", indexedVectorsCount: 0, pointsCount: 2000, segmentsCount: 5,
            config: CollectionConfig(
                params: CollectionParams(vectors: .single(VectorParams(size: 384, distance: .cosine)), shardNumber: 1, replicationFactor: 1, writeConsistencyFactor: 1, onDiskPayload: true),
                hnswConfig: HnswConfig(m: 16, efConstruct: 100),
                optimizerConfig: OptimizerConfig(indexingThreshold: 10000)),
            payloadSchema: [:], updateQueue: UpdateQueue(length: 0))
        return CollectionDetailBundle(
            name: "docs_embeddings", detail: detail, aliases: [], snapshots: [],
            optimizations: OptimizationsInfo(summary: OptimizationsSummary(queuedOptimizations: 0, idleSegments: 5), running: []),
            rawJSON: "{}")
    }

    private static func make(_ connection: ConnectionState, tab: AppState.DashboardTab, degraded: Bool = false) -> AppState {
        let state = AppState(startServices: false)
        state.themeMode = .dark
        state.selectedTab = tab
        state.connection = connection
        state.lastChecked = Date().addingTimeInterval(-2)
        guard connection != .offline else { return state }
        state.latencyMs = 44
        state.latencyHistory = [52, 48, 61, 44, 47, 43, 58, 45, 44, 46, 42, 44, 49, 43, 44, 44]
        guard connection == .online else { return state }
        state.version = QdrantVersion(title: "qdrant", version: "1.19.1")
        state.collections = [
            item("docs_embeddings", points: 2000, dims: 384, metric: .cosine, segments: 8, status: .green),
            item("support_tickets", points: 800, dims: 128, metric: .dot, segments: 4, status: degraded ? .yellow : .green),
            item("product_catalog", points: 500, dims: 64, metric: .euclid, segments: 3, status: .green),
        ]
        return state
    }

    private static func item(_ name: String, points: Int, dims: Int, metric: DistanceMetric, segments: Int, status: CollectionStatus) -> CollectionItem {
        let params = CollectionParams(vectors: .single(VectorParams(size: dims, distance: metric)))
        let detail = CollectionDetail(
            status: status, optimizerStatus: "ok", vectorsCount: points, indexedVectorsCount: points,
            pointsCount: points, segmentsCount: segments, config: CollectionConfig(params: params)
        )
        return CollectionItem(name: name, detail: detail)
    }
}
#endif
