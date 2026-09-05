package com.theamorn.hybriddemo

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
 * The view hierarchy is deliberately not "Flutter inside a Composable":
 *
 *     FrameLayout
 *       ├── FragmentContainerView   ← FlutterFragment; a SurfaceView underneath
 *       │                             the window, hole-punched through it
 *       └── ComposeView             ← Home, the NavigationBar and the HUD,
 *                                     drawn into the window, i.e. on top
 *
 * That ordering is what keeps the Material `NavigationBar` and the HUD visible
 * over the Flutter surface while leaving Flutter on the fast SurfaceView path.
 * Putting Flutter inside an `AndroidView` would either need `RenderMode.texture`
 * — an extra GPU copy, which corrupts the very numbers the HUD exists to show —
 * or `TransparencyMode.transparent`, which z-orders the Flutter surface *above*
 * the window and hides the native chrome entirely.
 *
 * The Flutter container's bottom margin is set to the measured NavigationBar
 * height, so Flutter's viewport genuinely ends above the bar rather than merely
 * being covered by it. Same rule as iOS.
 */
class TabsActivity : FragmentActivity() {

    private companion object {
        const val TAB_HOME = 0
        const val TAB_GAME = 1
        const val FLUTTER_FRAGMENT_TAG = "flutter_game"
    }

    private lateinit var flutterContainer: FragmentContainerView
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
        root.addView(
            flutterContainer,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        val composeView = ComposeView(this).apply {
            setContent {
                HybridDemoTheme {
                    TabsScaffold(
                        selectedTab = selectedTab,
                        onSelectTab = ::selectTab,
                        onBottomBarHeight = ::applyBottomBarHeight,
                    )
                }
            }
        }
        root.addView(
            composeView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        setContentView(root)

        flutterFragmentAttached =
            supportFragmentManager.findFragmentByTag(FLUTTER_FRAGMENT_TAG) != null
        applySelection()
    }

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
            PerformanceHudState.setActiveFlutterRoute(AppEngines.GAME_ROUTE)
        } else {
            flutterContainer.visibility = View.GONE
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

    private fun applyBottomBarHeight(heightPx: Int) {
        if (heightPx == bottomBarHeightPx) return
        bottomBarHeightPx = heightPx
        val params = flutterContainer.layoutParams as FrameLayout.LayoutParams
        params.bottomMargin = heightPx
        flutterContainer.layoutParams = params
    }
}

@androidx.compose.runtime.Composable
private fun TabsScaffold(
    selectedTab: Int,
    onSelectTab: (Int) -> Unit,
    onBottomBarHeight: (Int) -> Unit,
) {
    Scaffold(
        // Transparent so the hole-punched Flutter surface below the window is
        // visible through the Scaffold body on the game tab.
        containerColor = Color.Transparent,
        contentColor = androidx.compose.material3.MaterialTheme.colorScheme.onSurface,
        bottomBar = {
            NavigationBar(modifier = Modifier.onSizeChanged { onBottomBarHeight(it.height) }) {
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
        },
    ) { insets ->
        Box(modifier = Modifier.fillMaxSize()) {
            when (selectedTab) {
                0 -> HomeScreen(contentPadding = insets)
                // The game tab draws nothing: Flutter is behind this window.
                else -> Box(Modifier.fillMaxSize())
            }

            PerformanceHud(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(
                        top = insets.calculateTopPadding() + 8.dp,
                        end = 8.dp,
                        start = 8.dp,
                    ),
            )
        }
    }
}
