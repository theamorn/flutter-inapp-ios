package com.theamorn.hybriddemo

import android.content.Context
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode

/**
 * Two tabs: native Home, and the Flutter game. Mirrors
 * `cool-ios/cool-ios/MainTabBarController.swift` and
 * `FlutterTabViewController.swift`.
 *
 * ## Why the hierarchy is hand-built rather than "Flutter inside a Composable"
 *
 *     FrameLayout
 *       ├── FragmentContainerView   ← FlutterFragment. A SurfaceView, so its
 *       │                             buffer sits under the window and it
 *       │                             hole-punches through. Bottom margin =
 *       │                             nav bar height, so Flutter's viewport
 *       │                             genuinely ends above the bar.
 *       ├── ComposeView  body       ← Home. GONE on the game tab.
 *       ├── ComposeView  chrome     ← the NavigationBar, bottom-aligned only.
 *       └── PassThroughHost         ← the HUD, top-right, touch-transparent.
 *
 * Three separate Compose islands rather than one full-screen `Scaffold`,
 * because **a full-screen `ComposeView` swallows every touch.**
 * `AndroidComposeView.dispatchTouchEvent` returns true once it has dispatched a
 * pointer event, whether or not anything consumed it, so an "empty" Compose
 * body over the Flutter surface silently eats taps — the game renders, animates,
 * and never responds. Sizing each Compose island to the chrome it actually
 * draws lets `ViewGroup` dispatch fall through to the Flutter view underneath.
 *
 * This also mirrors iOS structurally: the tab bar and the HUD are separate from
 * the content view, and the HUD has `isUserInteractionEnabled = false`.
 *
 * `RenderMode.surface` + `TransparencyMode.opaque` is deliberate.
 * `RenderMode.texture` would put Flutter on a TextureView — an extra GPU copy
 * per frame, which corrupts the very numbers the HUD exists to show — and
 * `TransparencyMode.transparent` z-orders the Flutter surface *above* the
 * window, hiding the native chrome entirely.
 */
class TabsActivity : FragmentActivity() {

    private companion object {
        const val TAB_HOME = 0
        const val TAB_GAME = 1
        const val FLUTTER_FRAGMENT_TAG = "flutter_game"
    }

    private lateinit var flutterContainer: FragmentContainerView
    private lateinit var bodyView: ComposeView
    private var flutterFragmentAttached = false
    private var selectedTab by mutableIntStateOf(TAB_HOME)
    private var bottomBarHeightPx = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val root = FrameLayout(this)

        flutterContainer = FragmentContainerView(this).apply {
            id = View.generateViewId()
            visibility = View.GONE
        }
        root.addView(flutterContainer, matchParent())

        bodyView = ComposeView(this).apply {
            setContent {
                HybridDemoTheme {
                    if (selectedTab == TAB_HOME) HomeTab()
                }
            }
        }
        root.addView(bodyView, matchParent())

        val chromeView = ComposeView(this).apply {
            setContent {
                HybridDemoTheme {
                    TabBar(
                        selectedTab = selectedTab,
                        onSelectTab = ::selectTab,
                        onHeight = ::applyBottomBarHeight,
                    )
                }
            }
        }
        root.addView(
            chromeView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )

        val hudHost = PassThroughHost(this).apply {
            addView(
                ComposeView(context).apply {
                    setContent { HybridDemoTheme { HudOverlay() } }
                },
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
        root.addView(hudHost, matchParent())

        setContentView(root)

        flutterFragmentAttached =
            supportFragmentManager.findFragmentByTag(FLUTTER_FRAGMENT_TAG) != null
        applySelection()
    }

    private fun matchParent() = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
    )

    override fun onResume() {
        super.onResume()
        PerformanceHudState.start(this)
    }

    override fun onPause() {
        PerformanceHudState.stop()
        super.onPause()
    }

    /**
     * `FlutterFragment` needs this forwarded or the engine's lifecycle channel
     * never reaches `resumed` and Flutter renders nothing — with no error.
     */
    override fun onPostResume() {
        super.onPostResume()
        flutterFragment()?.onPostResume()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        flutterFragment()?.onTrimMemory(level)
    }

    private fun flutterFragment(): FlutterFragment? =
        supportFragmentManager.findFragmentByTag(FLUTTER_FRAGMENT_TAG) as? FlutterFragment

    private fun selectTab(index: Int) {
        if (selectedTab == index) return
        selectedTab = index
        applySelection()
    }

    private fun applySelection() {
        if (selectedTab == TAB_GAME) {
            // Lazy spawn: the engine is created on the tab's *first* selection,
            // never at launch. That is what lets the HUD show the real
            // incremental cost of the engine as the presenter taps into it.
            ensureFlutterFragment()
            flutterContainer.visibility = View.VISIBLE
            // GONE, not INVISIBLE: an INVISIBLE ComposeView still takes touches.
            bodyView.visibility = View.GONE
            PerformanceHudState.setActiveFlutterRoute(AppEngines.GAME_ROUTE)
        } else {
            flutterContainer.visibility = View.GONE
            bodyView.visibility = View.VISIBLE
            PerformanceHudState.setActiveFlutterRoute(null)
        }
    }

    private fun ensureFlutterFragment() {
        if (flutterFragmentAttached) return
        flutterFragmentAttached = true

        // Spawns the engine and starts the deferred spawn-cost measurement.
        AppEngines.engineForRoute(this, AppEngines.GAME_ROUTE)

        val fragment = FlutterFragment
            .withCachedEngine(AppEngines.cacheKey(AppEngines.GAME_ROUTE))
            .renderMode(RenderMode.surface)
            .transparencyMode(TransparencyMode.opaque)
            .shouldAttachEngineToActivity(true)
            .destroyEngineWithFragment(false)
            .build<FlutterFragment>()

        supportFragmentManager
            .beginTransaction()
            .add(flutterContainer.id, fragment, FLUTTER_FRAGMENT_TAG)
            .commitNow()
    }

    /** Keeps both the Flutter surface and Home content clear of the tab bar. */
    private fun applyBottomBarHeight(heightPx: Int) {
        if (heightPx == bottomBarHeightPx) return
        bottomBarHeightPx = heightPx
        listOf<View>(flutterContainer, bodyView).forEach { view ->
            val params = view.layoutParams as FrameLayout.LayoutParams
            params.bottomMargin = heightPx
            view.layoutParams = params
        }
    }
}

/**
 * A container that never handles touches, so `ViewGroup` dispatch continues to
 * the views beneath it. The Android equivalent of the iOS HUD's
 * `isUserInteractionEnabled = false`.
 */
private class PassThroughHost(context: Context) : FrameLayout(context) {
    override fun dispatchTouchEvent(ev: MotionEvent): Boolean = false
    override fun onTouchEvent(event: MotionEvent): Boolean = false
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeTab() {
    Scaffold(
        topBar = {
            // iOS wraps Home (but not the Flutter tab) in a UINavigationController
            // with a large "Home" title. Mirror that.
            LargeTopAppBar(
                title = { Text("Home") },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
                    scrolledContainerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
                ),
            )
        },
        // The host View already stops above the tab bar, so the Scaffold must
        // not add a bottom inset of its own on top of that.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { insets ->
        HomeScreen(contentPadding = insets)
    }
}

@Composable
private fun TabBar(
    selectedTab: Int,
    onSelectTab: (Int) -> Unit,
    onHeight: (Int) -> Unit,
) {
    NavigationBar(modifier = Modifier.onSizeChanged { onHeight(it.height) }) {
        NavigationBarItem(
            selected = selectedTab == 0,
            onClick = { onSelectTab(0) },
            icon = {
                Icon(
                    if (selectedTab == 0) Icons.Filled.Home else Icons.Outlined.Home,
                    contentDescription = null,
                )
            },
            label = { Text("Home") },
        )
        NavigationBarItem(
            selected = selectedTab == 1,
            onClick = { onSelectTab(1) },
            icon = {
                Icon(
                    if (selectedTab == 1) Icons.Filled.SportsEsports else Icons.Outlined.SportsEsports,
                    contentDescription = null,
                )
            },
            label = { Text("Game") },
        )
    }
}

@Composable
private fun HudOverlay() {
    Box(modifier = Modifier.fillMaxSize()) {
        PerformanceHud(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(
                    top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 8.dp,
                    end = 8.dp,
                    start = 8.dp,
                ),
        )
    }
}
