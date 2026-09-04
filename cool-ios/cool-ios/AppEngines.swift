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

        let spawnMillis = (CACurrentMediaTime() - start) * 1_000
        let memoryAfter = MemoryProbe.footprintBytes()
        let memoryDelta = Int64(memoryAfter) - Int64(memoryBefore)

        attachTelemetryChannel(to: engine, route: route)
        engines[route] = engine
        PerformanceHUDView.shared.recordEngineSpawn(
            route: route,
            deltaBytes: memoryDelta,
            durationMillis: spawnMillis
        )
        return engine
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

            let reportedRoute = payload["route"] as? String
            let sampleRoute = reportedRoute == route ? reportedRoute! : route
            DispatchQueue.main.async {
                PerformanceHUDView.shared.recordFlutterSample(
                    route: sampleRoute,
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
