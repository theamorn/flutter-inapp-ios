package com.theamorn.hybriddemo

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Choreographer
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Host-side telemetry, owned by the native app and never by Flutter.
 *
 * The Android half of `cool-ios/cool-ios/PerformanceHUDView.swift`: same
 * metrics, same line formats, same visual design, so the two hosts can be
 * photographed side by side. Cadence comes from [Choreographer] (iOS uses
 * `CADisplayLink`) and memory from [MemoryProbe].
 */
object PerformanceHudState {

    enum class DisplayMode {
        EXPANDED,
        MINIMIZED,
    }

    var displayMode by mutableStateOf(DisplayMode.EXPANDED)

    fun toggleDisplayMode() {
        displayMode = if (displayMode == DisplayMode.EXPANDED) {
            DisplayMode.MINIMIZED
        } else {
            DisplayMode.EXPANDED
        }
    }

    private data class FlutterSample(
        val uiMillis: Double,
        val rasterMillis: Double,
        val fps: Double,
        val receivedAtMillis: Long,
    )

    private data class EngineSpawn(
        val deltaBytes: Long,
        val durationMillis: Double,
    )

    private const val MEMORY_SAMPLE_INTERVAL_NANOS = 1_000_000_000L

    var hostFps by mutableStateOf(0.0)
        private set
    var memoryBytes by mutableStateOf(0L)
        private set
    var panelDescription by mutableStateOf("")
        private set

    private var activeRoute by mutableStateOf<String?>(null)
    private var sampleTimeMillis by mutableStateOf(0L)
    private var flutterSamples by mutableStateOf(mapOf<String, FlutterSample>())
    private var engineSpawns by mutableStateOf(mapOf<String, EngineSpawn>())

    private var frameCount = 0
    private var sampleStartNanos: Long? = null
    private var lastMemorySampleNanos = 0L
    private var running = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val memoryExecutor = Executors.newSingleThreadExecutor()

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!running) return
            Choreographer.getInstance().postFrameCallback(this)

            val start = sampleStartNanos
            if (start == null) {
                sampleStartNanos = frameTimeNanos
                frameCount = 0
                return
            }

            frameCount += 1
            val elapsed = frameTimeNanos - start
            if (elapsed < 1_000_000_000L) return

            // Advance observable time even when FPS/PSS are unchanged, so
            // a static tab's last Flutter sample still expires in Compose.
            sampleTimeMillis = SystemClock.elapsedRealtime()
            hostFps = frameCount * 1_000_000_000.0 / elapsed
            sampleStartNanos = frameTimeNanos
            frameCount = 0

            // Debug.getMemoryInfo walks /proc and costs single-digit
            // milliseconds; never do it on the thread that feeds Flutter vsync.
            if (frameTimeNanos - lastMemorySampleNanos >= MEMORY_SAMPLE_INTERVAL_NANOS) {
                lastMemorySampleNanos = frameTimeNanos
                memoryExecutor.execute {
                    val bytes = MemoryProbe.footprintBytes()
                    mainHandler.post {
                        if (running) memoryBytes = bytes
                    }
                }
            }
        }
    }

    fun start(context: Context) {
        if (panelDescription.isEmpty()) {
            panelDescription = describePanel(context)
        }
        if (running) return
        running = true
        sampleTimeMillis = SystemClock.elapsedRealtime()
        hostFps = 0.0
        flutterSamples = emptyMap()
        sampleStartNanos = null
        frameCount = 0
        memoryBytes = MemoryProbe.footprintBytes()
        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    fun stop() {
        running = false
        Choreographer.getInstance().removeFrameCallback(frameCallback)
        sampleStartNanos = null
        frameCount = 0
    }

    fun setActiveFlutterRoute(route: String?) {
        if (route != activeRoute && route != null) flutterSamples = flutterSamples - route
        activeRoute = route
    }

    fun recordFlutterSample(route: String, uiMillis: Double, rasterMillis: Double, fps: Double) {
        flutterSamples = flutterSamples +
            (route to FlutterSample(uiMillis, rasterMillis, fps, SystemClock.elapsedRealtime()))
    }

    fun recordEngineSpawn(route: String, deltaBytes: Long, durationMillis: Double) {
        engineSpawns = engineSpawns + (route to EngineSpawn(deltaBytes, durationMillis))
    }

    fun hostLine(): String = String.format(
        Locale.US,
        "HOST     %5.1f fps   %6.1f MiB PSS",
        hostFps,
        memoryBytes / 1_048_576.0,
    )

    fun flutterLine(): String {
        val routeToShow = activeRoute
        val sample = routeToShow?.let { flutterSamples[it] }
        return when {
            routeToShow != null && sample != null &&
                sampleTimeMillis - sample.receivedAtMillis <= 2_000 -> String.format(
                Locale.US,
                "FLUTTER  %s  UI %.1f ms  raster %.1f ms  %.0f fps",
                routeToShow,
                sample.uiMillis,
                sample.rasterMillis,
                sample.fps,
            )

            activeRoute != null -> "FLUTTER  $activeRoute  no recent frames"
            else -> "FLUTTER  —  no active Flutter engine"
        }
    }

    fun enginesLine(): String {
        val routeOrder = listOf(AppEngines.GAME_ROUTE, AppEngines.GLASS_ROUTE, AppEngines.SCENE_ROUTE)
        val summaries = routeOrder.mapNotNull { route ->
            val spawn = engineSpawns[route] ?: return@mapNotNull null
            String.format(
                Locale.US,
                "%s %+.1f MiB/%.0f ms create",
                route,
                spawn.deltaBytes / 1_048_576.0,
                spawn.durationMillis,
            )
        }
        return if (summaries.isEmpty()) {
            "ENGINES  lazy — none spawned"
        } else {
            "ENGINES  " + summaries.joinToString("  ")
        }
    }

    /**
     * Android has no single flag equivalent to iOS's
     * `CADisableMinimumFrameDurationOnPhone`: high-refresh behaviour is
     * per-device and per-mode. Naming the panel on the HUD is what keeps a
     * side-by-side iOS/Android comparison honest rather than confusing.
     */
    @Suppress("DEPRECATION")
    private fun describePanel(context: Context): String {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.display
        } else {
            null
        }
        val hz = display?.refreshRate
        val modes = display?.supportedModes?.maxOfOrNull { it.refreshRate }
        val model = "${Build.MODEL}"
        return buildString {
            append("PANEL    ")
            append(model)
            if (hz != null) {
                append(String.format(Locale.US, " · %.0f Hz", hz))
                if (modes != null && modes > hz + 1f) {
                    append(String.format(Locale.US, " (max %.0f)", modes))
                }
            }
        }
    }
}

/**
 * The HUD overlay. Colours, corner radius, border, type sizes and line formats
 * all mirror `PerformanceHUDView.swift`.
 */
@Composable
fun PerformanceHud(modifier: Modifier = Modifier) {
    val mode = PerformanceHudState.displayMode
    val hostText = PerformanceHudState.hostLine()
    val flutterText = PerformanceHudState.flutterLine()
    val enginesText = PerformanceHudState.enginesLine()
    val panelText = PerformanceHudState.panelDescription

    Box(
        modifier = modifier,
    ) {
        if (mode == PerformanceHudState.DisplayMode.MINIMIZED) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.Black.copy(alpha = 0.84f))
                    .border(1.dp, HudGreen.copy(alpha = 0.75f), RoundedCornerShape(14.dp))
                    .clickable { PerformanceHudState.toggleDisplayMode() }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .background(HudGreen, CircleShape),
                )
                Text(
                    text = String.format(Locale.US, "%.0f FPS ▾", PerformanceHudState.hostFps),
                    color = Color.White,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .widthIn(max = 520.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.Black.copy(alpha = 0.84f))
                    .border(1.dp, HudGreen.copy(alpha = 0.75f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 10.dp, vertical = 8.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "LIVE PERFORMANCE",
                        color = HudGreen,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        lineHeight = 15.sp,
                    )
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(HudGreen.copy(alpha = 0.18f))
                            .border(0.5.dp, HudGreen.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
                            .clickable { PerformanceHudState.toggleDisplayMode() }
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    ) {
                        Text(
                            text = "Hide ▴",
                            color = HudGreen,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 10.sp,
                        )
                    }
                }
                HudMetric(hostText)
                HudMetric(flutterText)
                HudMetric(enginesText)
                if (panelText.isNotEmpty()) {
                    Text(
                        text = panelText,
                        color = Color.White.copy(alpha = 0.55f),
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Normal,
                        fontSize = 10.sp,
                        lineHeight = 13.sp,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }
    }
}

/**
 * One metric line. Shrinks to fit rather than wrapping — the iOS labels set
 * `adjustsFontSizeToFitWidth` with `minimumScaleFactor = 0.75`, and a wrapped
 * line would change the HUD's height and break the side-by-side photo.
 */
@Composable
private fun HudMetric(text: String) {
    BasicText(
        text = text,
        style = TextStyle(
            color = Color.White,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            lineHeight = 15.sp,
        ),
        maxLines = 1,
        autoSize = TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 12.sp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 2.dp),
    )
}

/** iOS `UIColor.systemGreen`, so the two HUDs photograph the same. */
private val HudGreen = Color(0xFF34C759)
