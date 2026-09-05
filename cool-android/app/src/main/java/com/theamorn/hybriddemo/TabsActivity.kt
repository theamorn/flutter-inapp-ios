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
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material.icons.filled.Opacity
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Landscape
import androidx.compose.material.icons.outlined.Opacity
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
 * Five tabs matching the iOS host (see `cool-ios/cool-ios/MainTabBarController.swift`):
 *   0. Home   (Native Material 3 Compose)
 *   1. Web    (Native Android WebView hosting bundled settings.html)
 *   2. Game   (Flutter /game, Flappy Cat)
 *   3. Glass  (Flutter /glass, Liquid Glass panel)
 *   4. Island (Flutter /scene, 3D Island scene with Flutter GPU)
 *
 * ## Hierarchy & Touch Dispatch
 *
 *     FrameLayout (root)
 *       ├── FragmentContainerView (game)     ← SurfaceView, GONE when inactive
 *       ├── FragmentContainerView (glass)    ← SurfaceView, GONE when inactive
 *       ├── FragmentContainerView (scene)    ← SurfaceView, GONE when inactive
 *       ├── WebTab (WebView)                 ← GONE when inactive
 *       ├── ComposeView (bodyView / Home)    ← GONE when inactive
 *       ├── ComposeView (chromeView)         ← Material 3 NavigationBar, bottom-aligned
 *       └── PassThroughHost (hudHost)        ← HUD overlay, top-right, touch-transparent
 *
 * Distinct views rather than a single full-screen Compose view ensure touches
 * fall through to Flutter surfaces and WebViews without being swallowed by Compose.
 *
 * `RenderMode.surface` + `TransparencyMode.opaque` sits below the window and
 * hole-punches through, keeping native chrome drawn cleanly on top.
 */
class TabsActivity : FragmentActivity() {

    private companion object {
        const val TAB_HOME = 0
        const val TAB_WEB = 1
        const val TAB_GAME = 2
        const val TAB_GLASS = 3
        const val TAB_SCENE = 4

        const val TAG_FLUTTER_GAME = "flutter_game"
        const val TAG_FLUTTER_GLASS = "flutter_glass"
        const val TAG_FLUTTER_SCENE = "flutter_scene"

        const val SELECTED_TAB_KEY = "selected_tab"
        const val ENGINE_GAME_CREATED_KEY = "engine_game_created"
        const val ENGINE_GLASS_CREATED_KEY = "engine_glass_created"
        const val ENGINE_SCENE_CREATED_KEY = "engine_scene_created"
    }

    private lateinit var gameContainer: FragmentContainerView
    private lateinit var glassContainer: FragmentContainerView
    private lateinit var sceneContainer: FragmentContainerView
    private lateinit var webTab: WebTab
    private lateinit var bodyView: ComposeView

    private var gameFragmentAttached = false
    private var glassFragmentAttached = false
    private var sceneFragmentAttached = false

    private var selectedTab by mutableIntStateOf(TAB_HOME)
    private var bottomBarHeightPx = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        selectedTab = savedInstanceState?.getInt(SELECTED_TAB_KEY, TAB_HOME) ?: TAB_HOME

        // FragmentManager restores cached-engine fragments during super.onCreate.
        // After process death the in-memory cache must be recreated first for any fragment that was attached.
        if (savedInstanceState?.getBoolean(ENGINE_GAME_CREATED_KEY) == true) {
            AppEngines.engineForRoute(this, AppEngines.GAME_ROUTE)
        }
        if (savedInstanceState?.getBoolean(ENGINE_GLASS_CREATED_KEY) == true) {
            AppEngines.engineForRoute(this, AppEngines.GLASS_ROUTE)
        }
        if (savedInstanceState?.getBoolean(ENGINE_SCENE_CREATED_KEY) == true) {
            AppEngines.engineForRoute(this, AppEngines.SCENE_ROUTE)
        }

        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val root = FrameLayout(this)

        gameContainer = FragmentContainerView(this).apply {
            id = R.id.flutter_container_game
            visibility = View.GONE
        }
        root.addView(gameContainer, matchParent())

        glassContainer = FragmentContainerView(this).apply {
            id = R.id.flutter_container_glass
            visibility = View.GONE
        }
        root.addView(glassContainer, matchParent())

        sceneContainer = FragmentContainerView(this).apply {
            id = R.id.flutter_container_scene
            visibility = View.GONE
        }
        root.addView(sceneContainer, matchParent())

        webTab = WebTab(this).apply {
            visibility = View.GONE
        }
        root.addView(webTab, matchParent())

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

        gameFragmentAttached = supportFragmentManager.findFragmentByTag(TAG_FLUTTER_GAME) != null
        glassFragmentAttached = supportFragmentManager.findFragmentByTag(TAG_FLUTTER_GLASS) != null
        sceneFragmentAttached = supportFragmentManager.findFragmentByTag(TAG_FLUTTER_SCENE) != null

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
     * never reaches `resumed` and Flutter renders nothing.
     */
    override fun onPostResume() {
        super.onPostResume()
        flutterFragments().forEach { it.onPostResume() }
        updateFlutterVisibility()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putInt(SELECTED_TAB_KEY, selectedTab)
        outState.putBoolean(ENGINE_GAME_CREATED_KEY, gameFragmentAttached)
        outState.putBoolean(ENGINE_GLASS_CREATED_KEY, glassFragmentAttached)
        outState.putBoolean(ENGINE_SCENE_CREATED_KEY, sceneFragmentAttached)
        super.onSaveInstanceState(outState)
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        flutterFragments().forEach { it.onTrimMemory(level) }
    }

    override fun onDestroy() {
        webTab.onDestroy()
        super.onDestroy()
    }

    private fun flutterFragments(): List<FlutterFragment> = listOfNotNull(
        supportFragmentManager.findFragmentByTag(TAG_FLUTTER_GAME) as? FlutterFragment,
        supportFragmentManager.findFragmentByTag(TAG_FLUTTER_GLASS) as? FlutterFragment,
        supportFragmentManager.findFragmentByTag(TAG_FLUTTER_SCENE) as? FlutterFragment,
    )

    private fun selectTab(index: Int) {
        if (selectedTab == index) return
        selectedTab = index
        applySelection()
    }

    private fun applySelection() {
        // 1. Content view visibility (GONE ensures non-active views do not intercept touches)
        bodyView.visibility = if (selectedTab == TAB_HOME) View.VISIBLE else View.GONE
        webTab.visibility = if (selectedTab == TAB_WEB) View.VISIBLE else View.GONE
        gameContainer.visibility = if (selectedTab == TAB_GAME) View.VISIBLE else View.GONE
        glassContainer.visibility = if (selectedTab == TAB_GLASS) View.VISIBLE else View.GONE
        sceneContainer.visibility = if (selectedTab == TAB_SCENE) View.VISIBLE else View.GONE

        // 2. Web active synchronization (suspends RAF and stress test when tab is hidden)
        webTab.setPageActive(selectedTab == TAB_WEB)

        // 3. Lazy spawn Flutter engine and fragment on first selection
        when (selectedTab) {
            TAB_GAME -> {
                ensureFlutterFragment(AppEngines.GAME_ROUTE, gameContainer.id, TAG_FLUTTER_GAME) {
                    gameFragmentAttached = true
                }
                PerformanceHudState.setActiveFlutterRoute(AppEngines.GAME_ROUTE)
            }
            TAB_GLASS -> {
                ensureFlutterFragment(AppEngines.GLASS_ROUTE, glassContainer.id, TAG_FLUTTER_GLASS) {
                    glassFragmentAttached = true
                }
                PerformanceHudState.setActiveFlutterRoute(AppEngines.GLASS_ROUTE)
            }
            TAB_SCENE -> {
                ensureFlutterFragment(AppEngines.SCENE_ROUTE, sceneContainer.id, TAG_FLUTTER_SCENE) {
                    sceneFragmentAttached = true
                }
                PerformanceHudState.setActiveFlutterRoute(AppEngines.SCENE_ROUTE)
            }
            else -> {
                PerformanceHudState.setActiveFlutterRoute(null)
            }
        }

        // 4. Update Flutter engine render loops (pauses inactive engines)
        updateFlutterVisibility()
    }

    private fun updateFlutterVisibility() {
        val routes = listOf(
            TAB_GAME to AppEngines.GAME_ROUTE,
            TAB_GLASS to AppEngines.GLASS_ROUTE,
            TAB_SCENE to AppEngines.SCENE_ROUTE,
        )
        for ((tabIndex, route) in routes) {
            val engine = AppEngines.getEngine(route) ?: continue
            val lifecycle = engine.lifecycleChannel
            if (selectedTab == tabIndex) {
                lifecycle.appIsResumed()
            } else {
                lifecycle.appIsPaused()
            }
        }
    }

    private fun ensureFlutterFragment(
        route: String,
        containerId: Int,
        tag: String,
        onAttached: () -> Unit,
    ) {
        if (supportFragmentManager.findFragmentByTag(tag) != null) return

        // Spawns the engine lazily and begins the deferred spawn-cost measurement.
        AppEngines.engineForRoute(this, route)

        val fragment = FlutterFragment
            .withCachedEngine(AppEngines.cacheKey(route))
            .renderMode(RenderMode.surface)
            .transparencyMode(TransparencyMode.opaque)
            .shouldAttachEngineToActivity(true)
            .destroyEngineWithFragment(false)
            .build<FlutterFragment>()

        supportFragmentManager
            .beginTransaction()
            .add(containerId, fragment, tag)
            .commitNow()

        onAttached()
    }

    /** Keeps all tab surfaces clear of the native bottom navigation bar. */
    private fun applyBottomBarHeight(heightPx: Int) {
        if (heightPx == bottomBarHeightPx) return
        bottomBarHeightPx = heightPx
        listOf<View>(bodyView, webTab, gameContainer, glassContainer, sceneContainer).forEach { view ->
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
            LargeTopAppBar(
                title = { Text("Home") },
                colors = TopAppBarDefaults.topAppBarColors(
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
    NavigationBar(
        modifier = Modifier.onSizeChanged { onHeight(it.height) },
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
    ) {
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
                    if (selectedTab == 1) Icons.Filled.Language else Icons.Outlined.Language,
                    contentDescription = null,
                )
            },
            label = { Text("Web") },
        )
        NavigationBarItem(
            selected = selectedTab == 2,
            onClick = { onSelectTab(2) },
            icon = {
                Icon(
                    if (selectedTab == 2) Icons.Filled.SportsEsports else Icons.Outlined.SportsEsports,
                    contentDescription = null,
                )
            },
            label = { Text("Game") },
        )
        NavigationBarItem(
            selected = selectedTab == 3,
            onClick = { onSelectTab(3) },
            icon = {
                Icon(
                    if (selectedTab == 3) Icons.Filled.Opacity else Icons.Outlined.Opacity,
                    contentDescription = null,
                )
            },
            label = { Text("Glass") },
        )
        NavigationBarItem(
            selected = selectedTab == 4,
            onClick = { onSelectTab(4) },
            icon = {
                Icon(
                    if (selectedTab == 4) Icons.Filled.Landscape else Icons.Outlined.Landscape,
                    contentDescription = null,
                )
            },
            label = { Text("Island") },
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
