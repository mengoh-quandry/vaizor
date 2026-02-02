import Foundation
import Network

/// Monitors network connectivity for hybrid online/offline artifact rendering
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }

    deinit {
        monitor.cancel()
    }
}

/// Configuration for artifact rendering mode
struct ArtifactRenderConfig {
    /// Whether to use CDN for additional libraries when online
    let useCDN: Bool

    /// CDN URLs for extended libraries (only used when online)
    static let cdnLibraries: [String: String] = [
        // Radix UI primitives for shadcn components
        "radix-ui-react-slot": "https://esm.sh/@radix-ui/react-slot@1.1.0",
        "radix-ui-react-dialog": "https://esm.sh/@radix-ui/react-dialog@1.0.5",
        "radix-ui-react-dropdown-menu": "https://esm.sh/@radix-ui/react-dropdown-menu@2.1.1",
        "radix-ui-react-tabs": "https://esm.sh/@radix-ui/react-tabs@1.0.4",
        "radix-ui-react-tooltip": "https://esm.sh/@radix-ui/react-tooltip@1.0.7",
        "radix-ui-react-popover": "https://esm.sh/@radix-ui/react-popover@1.0.7",
        "radix-ui-react-select": "https://esm.sh/@radix-ui/react-select@2.0.0",
        "radix-ui-react-checkbox": "https://esm.sh/@radix-ui/react-checkbox@1.0.4",
        "radix-ui-react-switch": "https://esm.sh/@radix-ui/react-switch@1.0.3",
        "radix-ui-react-slider": "https://esm.sh/@radix-ui/react-slider@1.1.2",
        "radix-ui-react-progress": "https://esm.sh/@radix-ui/react-progress@1.0.3",

        // Additional charting/viz when online
        "chart-js": "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js",
        "mapbox-gl": "https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.js",

        // Animation libraries
        "gsap": "https://cdn.jsdelivr.net/npm/gsap@3.12.4/dist/gsap.min.js",
        "lottie": "https://cdn.jsdelivr.net/npm/lottie-web@5.12.2/build/player/lottie.min.js",

        // 3D extended
        "three-examples": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/",
    ]

    /// Tailwind CDN URL
    static let tailwindCDN = "https://cdn.tailwindcss.com/3.4.17"

    /// Create config based on current network state
    @MainActor
    static func current() -> ArtifactRenderConfig {
        return ArtifactRenderConfig(useCDN: NetworkMonitor.shared.isConnected)
    }
}
