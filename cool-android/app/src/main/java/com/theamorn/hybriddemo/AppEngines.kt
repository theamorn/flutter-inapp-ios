package com.theamorn.hybriddemo

import android.content.Context
import android.os.Debug
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the demo's single engine group and its lazily-created engines.
 *
 * This is the Android half of `cool-ios/cool-ios/AppEngines.swift` and is
 * deliberately structured the same way, including the deferred spawn-cost
 * measurement. Names come from `docs/hybrid-demo/ARCHITECTURE.md`; do not
 * invent new ones — a mismatch here fails silently at runtime.
 */
object AppEngines {

    const val ENGINE_GROUP_NAME = "hybrid-demo"

    const val GAME_ROUTE = "/game"
    const val GLASS_ROUTE = "/glass"
    const val SCENE_ROUTE = "/scene"
    const val TELEMETRY_CHANNEL_NAME = "com.theamorn.hybrid/telemetry"

    /**
     * The Android host builds tabs 1 and 3 only (see `07-android-host.md`).
     * The other two routes exist in the contract and are listed so the
     * unsupported-route check stays honest about what this host can spawn.
     */
    private val supportedRoutes = setOf(GAME_ROUTE)

    private val mainHandler = Handler(Looper.getMainLooper())

    private var group: FlutterEngineGroup? = null
    private val engines = mutableMapOf<String, FlutterEngine>()
    private val telemetryChannels = mutableMapOf<String, MethodChannel>()

    /**
     * Spawn cost is finalised on an engine's first reported frame, not when
     * [FlutterEngineGroup.createAndRunEngine] returns. See [finalizeSpawnCost].
     */
    private data class PendingSpawn(
        val baselineBytes: Long,
        val durationMillis: Double,
    )

    private val pendingSpawns = mutableMapOf<String, PendingSpawn>()

    /** Cache key used with [FlutterEngineCache]; `FlutterFragment` looks it up by this. */
    fun cacheKey(route: String): String = "hybrid-demo${route.replace("/", ".")}"

    @Synchronized
    fun engineForRoute(context: Context, route: String): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "Engines must be created on the main thread"
        }
        engines[route]?.let { return it }

        require(route in supportedRoutes) { "Unsupported Flutter route: $route" }

        val appContext = context.applicationContext
        val engineGroup = group ?: FlutterEngineGroup(appContext).also { group = it }

        val memoryBefore = MemoryProbe.footprintBytes()
        val start = System.nanoTime()

        val engine = engineGroup.createAndRunEngine(
            appContext,
            DartExecutor.DartEntrypoint.createDefault(),
            route,
        )

        // createAndRunEngine returns as soon as the engine object exists and the
        // entrypoint has been handed to the Dart executor; the isolate is still
        // spinning up behind it. Sampling PSS here would miss most of the
        // engine's cost and read differently every run. The wall time below is
        // real, but the memory delta is deferred to the engine's first reported
        // frame, where the number is both stable and defensible: what this tab
        // actually costs once it is live and rendering.
        val spawnMillis = (System.nanoTime() - start) / 1_000_000.0

        pendingSpawns[route] = PendingSpawn(
            baselineBytes = memoryBefore,
            durationMillis = spawnMillis,
        )

        attachTelemetryChannel(engine, route)
        FlutterEngineCache.getInstance().put(cacheKey(route), engine)
        engines[route] = engine
        return engine
    }

    /**
     * Closes out a deferred spawn measurement on the engine's first frame.
     * A no-op for every frame after the first.
     */
    private fun finalizeSpawnCost(route: String) {
        val pending = pendingSpawns.remove(route) ?: return
        val delta = MemoryProbe.footprintBytes() - pending.baselineBytes
        PerformanceHudState.recordEngineSpawn(
            route = route,
            deltaBytes = delta,
            durationMillis = pending.durationMillis,
        )
    }

    private fun attachTelemetryChannel(engine: FlutterEngine, route: String) {
        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            TELEMETRY_CHANNEL_NAME,
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method != "reportFrameTimings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val uiMillis = call.argument<Number>("uiMillis")?.toDouble()
            val rasterMillis = call.argument<Number>("rasterMillis")?.toDouble()
            val fps = call.argument<Number>("fps")?.toDouble()
            if (uiMillis == null || rasterMillis == null || fps == null) {
                result.error(
                    "invalid_telemetry",
                    "Expected uiMillis, rasterMillis, and fps numbers",
                    null,
                )
                return@setMethodCallHandler
            }

            // The engine this channel belongs to is authoritative; a mismatched
            // 'route' in the payload would mean the Dart side is misreporting.
            mainHandler.post {
                finalizeSpawnCost(route)
                PerformanceHudState.recordFlutterSample(
                    route = route,
                    uiMillis = uiMillis,
                    rasterMillis = rasterMillis,
                    fps = fps,
                )
            }
            result.success(null)
        }
        telemetryChannels[route] = channel
    }
}

/**
 * Process memory, measured natively. Never sourced from Flutter — if Flutter
 * measured its own footprint the audience could reasonably call the meter rigged.
 *
 * iOS quotes `task_vm_info.phys_footprint`. The closest Android equivalent, and
 * the number Android Studio's memory profiler shows, is total PSS.
 */
object MemoryProbe {
    fun footprintBytes(): Long {
        val info = Debug.MemoryInfo()
        Debug.getMemoryInfo(info)
        // Debug.MemoryInfo reports in kB.
        return info.totalPss.toLong() * 1024L
    }
}
