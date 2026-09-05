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
     * All three Flutter routes supported by the demo contract.
     * Engines are created lazily on the tab's first appearance.
     */
    private val supportedRoutes = setOf(GAME_ROUTE, GLASS_ROUTE, SCENE_ROUTE)

    /** Returns the engine for [route] if already created, or null. */
    fun getEngine(route: String): FlutterEngine? = engines[route]

    private val mainHandler = Handler(Looper.getMainLooper())

    private var group: FlutterEngineGroup? = null
    private val engines = mutableMapOf<String, FlutterEngine>()
    private val telemetryChannels = mutableMapOf<String, MethodChannel>()

    /**
     * Spawn memory is sampled on an engine's first telemetry batch, not when
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

        // This times the synchronous creation call, not time-to-first-frame.
        // Memory is sampled at the first telemetry batch: a process-wide delta
        // including concurrent allocations and initial assets, not isolated
        // engine memory or a settled tab footprint.
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
     * Closes out a deferred memory measurement on the first telemetry batch.
     * A no-op for subsequent batches.
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
 * iOS uses physical footprint; this host uses total PSS. These are distinct
 * accounting methods and must not be presented as an identical metric.
 */
object MemoryProbe {
    fun footprintBytes(): Long {
        val info = Debug.MemoryInfo()
        Debug.getMemoryInfo(info)
        // Debug.MemoryInfo reports in kB.
        return info.totalPss.toLong() * 1024L
    }
}
