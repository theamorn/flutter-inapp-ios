package com.theamorn.hybriddemo

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Outline
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformPlugin
import kotlin.math.max

/** Matches `HoloCardGame.backdropColor`, so the tile has no flash and no seam. */
private const val PROMO_BACKDROP = 0xFF0C0A1C.toInt()

/**
 * The Android half of the `com.theamorn.hybrid/promo` contract; the table is
 * in `docs/hybrid-demo/ARCHITECTURE.md`, and the iOS half is
 * `InlineFlutterCardViewController.swift`.
 *
 * All positions cross the channel in Flutter logical pixels (dp); this class
 * converts to and from Android pixels with [density].
 */
class PromoTileController(
    val engine: FlutterEngine,
    private val density: Float,
    private val onClaim: (String) -> Unit,
) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, AppEngines.PROMO_CHANNEL_NAME)
    private var badgeBounds: RectF? = null
    private var sentVisible: Boolean? = null
    private var visible = true
    private var progress = 0.0
    private var lastScrollPx: Int? = null
    private var lastScrollNanos = 0L

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    sentVisible = visible
                    result.success(mapOf("visible" to visible, "progress" to progress))
                }
                "badgeBounds" -> {
                    val x = call.argument<Number>("x")?.toFloat()
                    val y = call.argument<Number>("y")?.toFloat()
                    val width = call.argument<Number>("w")?.toFloat()
                    val height = call.argument<Number>("h")?.toFloat()
                    if (x == null || y == null || width == null || height == null) {
                        result.error("invalid_bounds", "Expected x, y, w, and h numbers", null)
                    } else {
                        badgeBounds = RectF(x, y, x + width, y + height).apply {
                            left *= density
                            top *= density
                            right *= density
                            bottom *= density
                        }
                        result.success(null)
                    }
                }
                "claimPromo" -> {
                    onClaim(call.argument<String>("code").orEmpty())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Reports where the tile sits, from its and the viewport's window
     * positions in pixels, and the page's scroll offset in pixels.
     */
    fun report(tileTopPx: Float, tileHeightPx: Int, viewportTopPx: Float, viewportHeightPx: Int, scrollPx: Int) {
        val margin = VISIBILITY_MARGIN_DP * density
        val tileBottomPx = tileTopPx + tileHeightPx
        visible = tileBottomPx > viewportTopPx - margin &&
            tileTopPx < viewportTopPx + viewportHeightPx + margin
        val halfViewport = max(viewportHeightPx / 2f, 1f)
        val tileCenter = tileTopPx + tileHeightPx / 2f
        progress = ((tileCenter - (viewportTopPx + halfViewport)) / halfViewport)
            .coerceIn(-1.5f, 1.5f)
            .toDouble()
        sendVisibility(visible)

        // Layout can report the same position more than once per frame; only
        // an actual scroll is a velocity sample.
        val now = System.nanoTime()
        val lastPx = lastScrollPx
        if (lastPx == scrollPx) return
        val seconds = (now - lastScrollNanos) / 1e9
        val velocity = if (lastPx != null && seconds > 0) (scrollPx - lastPx) / seconds / density else 0.0
        lastScrollPx = scrollPx
        lastScrollNanos = now
        if (visible) {
            channel.invokeMethod("scroll", mapOf("progress" to progress, "velocity" to velocity))
        }
    }

    /** Sent only on change, unless [force]d after the two sides may have drifted. */
    fun sendVisibility(visible: Boolean, force: Boolean = false) {
        if (!force && visible == sentVisible) return
        sentVisible = visible
        channel.invokeMethod("visibility", mapOf("visible" to visible))
    }

    /** Whether a touch starting at ([x], [y]) tile pixels belongs to the badge. */
    fun ownsTouch(x: Float, y: Float): Boolean {
        val bounds = badgeBounds ?: return false
        val slop = TOUCH_SLOP_DP * density
        return x >= bounds.left - slop && x <= bounds.right + slop &&
            y >= bounds.top - slop && y <= bounds.bottom + slop
    }

    fun dispose() = channel.setMethodCallHandler(null)

    private companion object {
        /** A tile this close to the viewport is already drawing when it arrives. */
        const val VISIBILITY_MARGIN_DP = 120f

        /** The reported bounds can be a frame or two behind a moving badge. */
        const val TOUCH_SLOP_DP = 16f
    }
}

/**
 * The `/promo` engine as a fixed-size tile inside a Compose page.
 *
 * Unlike the full-screen tabs, which use `FlutterFragment`, this hosts a bare
 * `FlutterView`: the official add-to-app pattern for Flutter inside a native
 * list. It renders into a `TextureView`, which composites like any other view,
 * so it clips to rounded corners and moves in step with Compose scrolling.
 */
@Composable
fun InlineFlutterTile(controller: PromoTileController, modifier: Modifier = Modifier) {
    val activity = LocalContext.current.findActivity()
    AndroidView(
        modifier = modifier,
        factory = { context -> BadgeTouchGate(context, activity, controller) },
        onRelease = { gate -> gate.release() },
    )
}

/**
 * Hosts the `FlutterView`, and hands a drag that starts on the badge to
 * Flutter before the page's scroll can claim it.
 */
@SuppressLint("ViewConstructor")
private class BadgeTouchGate(
    context: Context,
    activity: Activity,
    private val controller: PromoTileController,
) : FrameLayout(context) {
    private val flutterView = FlutterView(context, FlutterTextureView(context))

    // A bare FlutterView gets no platform plugin from a fragment delegate;
    // without one, HapticFeedback and other platform calls go unanswered.
    private val platformPlugin = PlatformPlugin(activity, controller.engine.platformChannel)

    init {
        setBackgroundColor(PROMO_BACKDROP)
        val radius = 16 * resources.displayMetrics.density
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
        clipToOutline = true

        // The tile sits mid-page: system bar insets never apply to it, and
        // forwarding them would change Flutter's viewport metrics for nothing.
        ViewCompat.setOnApplyWindowInsetsListener(flutterView) { _, _ -> WindowInsetsCompat.CONSUMED }
        addView(flutterView, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        flutterView.attachToFlutterEngine(controller.engine)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN && controller.ownsTouch(event.x, event.y)) {
            // Compose's AndroidView honors this: the page's verticalScroll
            // stops competing for the gesture that follows.
            parent?.requestDisallowInterceptTouchEvent(true)
        }
        return super.dispatchTouchEvent(event)
    }

    fun release() {
        flutterView.detachFromFlutterEngine()
        platformPlugin.destroy()
    }
}

private tailrec fun Context.findActivity(): Activity = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> error("InlineFlutterTile needs an Activity context")
}
