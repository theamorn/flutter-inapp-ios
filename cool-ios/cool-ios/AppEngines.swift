import Flutter
import QuartzCore

/// Owns the demo's single engine group and its three long-lived, lazily-created engines.
final class AppEngines {
    static let shared = AppEngines()

    static let gameRoute = "/game"
    static let glassRoute = "/glass"
    static let sceneRoute = "/scene"
    static let telemetryChannelName = "com.theamorn.hybrid/telemetry"

    private static let supportedRoutes = [gameRoute, glassRoute, sceneRoute]

    private let group = FlutterEngineGroup(name: "hybrid-demo", project: nil)
    private var engines: [String: FlutterEngine] = [:]
    private var telemetryChannels: [String: FlutterMethodChannel] = [:]

    /// Spawn cost is finalised on an engine's first reported frame, not when
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

        // makeEngine returns as soon as the engine object exists; the Dart
        // isolate is still spinning up behind it. Sampling phys_footprint here
        // would miss most of the engine's cost and read differently every run.
        // The wall time below is real, but the memory delta is deferred to the
        // engine's first frame, where the number is both stable and defensible:
        // what this tab actually costs once it is live and rendering.
        let spawnMillis = (CACurrentMediaTime() - start) * 1_000

        pendingSpawns[route] = PendingSpawn(
            baselineBytes: memoryBefore,
            durationMillis: spawnMillis
        )

        attachTelemetryChannel(to: engine, route: route)
        engines[route] = engine
        return engine
    }

    /// Closes out a deferred spawn measurement on the engine's first frame.
    /// A no-op for every frame after the first.
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
