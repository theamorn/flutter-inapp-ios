import Flutter
import QuartzCore

/// Owns the demo's single engine group and its long-lived, lazily-created engines.
final class AppEngines {
    static let shared = AppEngines()

    static let gameRoute = "/game"
    static let glassRoute = "/glass"
    static let promoRoute = "/promo"
    static let sceneRoute = "/scene"
    static let telemetryChannelName = "com.theamorn.hybrid/telemetry"
    static let gameChannelName = "com.theamorn.hybrid/game"
    static let promoChannelName = "com.theamorn.hybrid/promo"

    /// `/glass` has no tab since Shop replaced it, but stays supported so the
    /// Glass tab can come back with one line in `MainTabBarController`.
    private static let supportedRoutes = [gameRoute, glassRoute, promoRoute, sceneRoute]

    private let group = FlutterEngineGroup(name: "hybrid-demo", project: nil)
    private var engines: [String: FlutterEngine] = [:]
    private var telemetryChannels: [String: FlutterMethodChannel] = [:]

    /// Spawn memory is sampled on an engine's first telemetry batch, not when
    /// makeEngine returns. See `finalizeSpawnCost(for:)`.
    private struct PendingSpawn {
        let baselineBytes: UInt64
        let durationMillis: Double
    }
    private var pendingSpawns: [String: PendingSpawn] = [:]

    private init() {}

    func engine(forRoute route: String) -> FlutterEngine {
        dispatchPrecondition(condition: .onQueue(.main))

        if let existing = engines[route] {
            return existing
        }

        precondition(
            Self.supportedRoutes.contains(route),
            "Unsupported Flutter route: \(route)"
        )

        let memoryBefore = MemoryProbe.footprintBytes()
        let start = CACurrentMediaTime()

        let options = FlutterEngineGroupOptions()
        options.initialRoute = route
        let engine = group.makeEngine(with: options)

        // This times the synchronous creation call, not time-to-first-frame.
        // Memory is sampled at the first telemetry batch: a process-wide delta
        // including concurrent allocations and initial assets, not isolated
        // engine memory. Scene asset loading may still be in progress then.
        let spawnMillis = (CACurrentMediaTime() - start) * 1_000

        pendingSpawns[route] = PendingSpawn(
            baselineBytes: memoryBefore,
            durationMillis: spawnMillis
        )

        attachTelemetryChannel(to: engine, route: route)
        if route == Self.gameRoute {
            attachGameChannel(to: engine)
        }
        engines[route] = engine
        return engine
    }

    private func attachGameChannel(to engine: FlutterEngine) {
        let channel = FlutterMethodChannel(
            name: Self.gameChannelName,
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "reportScore" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let score: Int?
            if let payload = call.arguments as? [String: Any] {
                score = (payload["score"] as? NSNumber)?.intValue ?? payload["score"] as? Int
            } else if let number = call.arguments as? NSNumber {
                score = number.intValue
            } else {
                score = call.arguments as? Int
            }

            if let validScore = score {
                DispatchQueue.main.async {
                    GameScoreManager.shared.updateScore(validScore)
                }
            }
            result(nil)
        }
    }

    /// Closes out a deferred memory measurement on the first telemetry batch.
    /// A no-op for subsequent batches.
    private func finalizeSpawnCost(for route: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let pending = pendingSpawns.removeValue(forKey: route) else { return }

        let delta = Int64(MemoryProbe.footprintBytes()) - Int64(pending.baselineBytes)
        PerformanceHUDView.shared.recordEngineSpawn(
            route: route,
            deltaBytes: delta,
            durationMillis: pending.durationMillis
        )
    }

    private func attachTelemetryChannel(to engine: FlutterEngine, route: String) {
        let channel = FlutterMethodChannel(
            name: Self.telemetryChannelName,
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "reportFrameTimings" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let payload = call.arguments as? [String: Any],
                  let uiMillis = Self.double(from: payload["uiMillis"]),
                  let rasterMillis = Self.double(from: payload["rasterMillis"]),
                  let fps = Self.double(from: payload["fps"]) else {
                result(FlutterError(
                    code: "invalid_telemetry",
                    message: "Expected uiMillis, rasterMillis, and fps numbers",
                    details: nil
                ))
                return
            }

            // The engine this channel belongs to is authoritative; a mismatched
            // 'route' in the payload would mean the Dart side is misreporting.
            DispatchQueue.main.async {
                self.finalizeSpawnCost(for: route)
                PerformanceHUDView.shared.recordFlutterSample(
                    route: route,
                    uiMillis: uiMillis,
                    rasterMillis: rasterMillis,
                    fps: fps
                )
            }
            result(nil)
        }
        telemetryChannels[route] = channel
    }

    private static func double(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }
}

enum MemoryProbe {
    static func footprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}

extension Notification.Name {
    static let gameScoreUpdated = Notification.Name("com.theamorn.hybrid.gameScoreUpdated")
}

final class GameScoreManager {
    static let shared = GameScoreManager()

    private let userDefaultsKey = "flappy_cat_highest_score"

    private(set) var highestScore: Int {
        get {
            UserDefaults.standard.integer(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }

    private init() {}

    func updateScore(_ score: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        if score > highestScore {
            highestScore = score
            NotificationCenter.default.post(name: .gameScoreUpdated, object: nil, userInfo: ["score": score])
        }
    }
}
