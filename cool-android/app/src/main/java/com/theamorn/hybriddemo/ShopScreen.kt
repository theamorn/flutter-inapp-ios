package com.theamorn.hybriddemo

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.SurroundSound
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.withFrameNanos
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import java.util.Locale
import kotlinx.coroutines.delay

private const val BASE_PRICE = 249f
private const val DISCOUNT = 0.2f
private const val PROMO_CODE = "HOLO20"

/** The 3D header's height, matching the iOS page. */
private val HEADER_HEIGHT = 280.dp

/** Space above the tab row once Review Details pins it. */
private val PINNED_GAP = 8.dp

/** The page's spacing between items, from its `Arrangement.spacedBy`. */
private val ITEM_SPACING = 8.dp

/** iOS systemIndigo: the 3D header's backdrop before its first frame. */
private const val HEADER_BACKDROP = 0xFF5856D6.toInt()

/** The Review Details tab's background, so there is no seam and no flash. */
private const val REVIEWS_BACKDROP = 0xFFF2F2F7.toInt()

private const val TAB_OVERVIEW = 0
private const val TAB_REVIEWS = 1

/**
 * Tab 4 on Android: a Material 3 product page with three Flutter views in it,
 * one engine each, mirroring `cool-ios/cool-ios/ProductDetailViewController.swift`
 * section for section:
 *
 * - `/product`, the 3D headphones at the top, which the user can orbit.
 * - `/promo`, the holo badge tile halfway down the Overview tab.
 * - `/reviews`, the whole Review Details tab, drawn with Liquid Glass: the
 *   iOS 27 material, on Android.
 *
 * Compose owns everything around them: layout, scrolling, the Overview |
 * Review Details switch, the price, and the success haptic. Flutter draws the
 * badge and, when it is tapped, hands back the promo code; this page fills
 * its own native promo field with it, validates it, and reprices.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopTab() {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shop") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
                ),
            )
        },
        // The host View already stops above the tab bar.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { insets ->
        ShopScreen(contentPadding = insets)
    }
}

/** The scroll viewport's window position, read by layout callbacks only. */
private class Viewport {
    var top = 0f
    var height = 0
}

/** Whether a view at [topPx]..[topPx]+[heightPx] in the window shows in [viewport]. */
private fun Viewport.shows(topPx: Float, heightPx: Int): Boolean =
    topPx + heightPx > top && topPx < top + height

@Composable
private fun ShopScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val view = LocalView.current
    val density = LocalDensity.current.density
    var discounted by rememberSaveable { mutableStateOf(false) }
    var promoCode by rememberSaveable { mutableStateOf("") }
    var promoRejected by remember { mutableStateOf(false) }
    var promoFlash by remember { mutableIntStateOf(0) }
    var color by remember { mutableIntStateOf(0) }
    val price by animateFloatAsState(
        targetValue = if (discounted) BASE_PRICE * (1 - DISCOUNT) else BASE_PRICE,
        animationSpec = tween(700),
        label = "price",
    )
    val scrollState = rememberScrollState()
    val viewport = remember { Viewport() }
    // Review Details fills the viewport below the pinned tab row, so its
    // height follows the viewport's: state, not a layout-only field.
    var viewportHeightPx by remember { mutableIntStateOf(0) }
    var tabRowTopPx by remember { mutableIntStateOf(0) }
    var tabRowHeightPx by remember { mutableIntStateOf(0) }
    var selectedTab by rememberSaveable { mutableIntStateOf(TAB_OVERVIEW) }
    // Processing a code is native logic, whether it was typed or came from Flutter.
    fun applyPromoCode() {
        if (promoCode.trim().uppercase(Locale.US) != PROMO_CODE) {
            promoRejected = true
            view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            return
        }
        promoRejected = false
        if (!discounted) {
            discounted = true
            view.confirmHaptic()
        }
    }
    val promo = remember {
        // Flutter only reports the code: the field fills in, then the page
        // validates it and reprices.
        PromoTileController(AppEngines.engineForRoute(context, AppEngines.PROMO_ROUTE), density) { code ->
            promoCode = code
            promoFlash++
            applyPromoCode()
        }
    }
    DisposableEffect(promo) { onDispose { promo.dispose() } }
    // TabsActivity already spawned these engines on the Shop tab's first
    // selection: never on the tab-row tap, where a synchronous engine start
    // would hitch it.
    val product = remember {
        FlutterSurfaceController(
            AppEngines.engineForRoute(context, AppEngines.PRODUCT_ROUTE),
            AppEngines.PRODUCT_CHANNEL_NAME,
        )
    }
    val reviews = remember {
        FlutterSurfaceController(
            AppEngines.engineForRoute(context, AppEngines.REVIEWS_ROUTE),
            AppEngines.REVIEWS_CHANNEL_NAME,
        )
    }
    DisposableEffect(product, reviews) {
        onDispose {
            product.dispose()
            reviews.dispose()
        }
    }
    LaunchedEffect(selectedTab) {
        PerformanceHudState.setActiveFlutterRoute(
            if (selectedTab == TAB_REVIEWS) AppEngines.REVIEWS_ROUTE else AppEngines.PRODUCT_ROUTE,
        )
        if (selectedTab == TAB_REVIEWS) {
            promo.sendVisibility(false)
            // Let the panel lay out first, so the page is long enough to
            // scroll the tab row up to the top. From there on, the list
            // inside the panel scrolls, and the page cannot.
            withFrameNanos { }
            withFrameNanos { }
            scrollState.animateScrollTo(tabRowTopPx - (PINNED_GAP.value * density).toInt())
        } else {
            reviews.sendVisibility(false)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceContainerLowest)
            .padding(contentPadding)
            .onGloballyPositioned {
                viewport.top = it.positionInWindow().y
                viewport.height = it.size.height
                viewportHeightPx = it.size.height
            }
            .verticalScroll(scrollState)
            // The Review Details panel reaches the bottom of the viewport.
            .padding(bottom = if (selectedTab == TAB_REVIEWS) 0.dp else 24.dp),
        verticalArrangement = Arrangement.spacedBy(ITEM_SPACING),
    ) {
        Hero(
            price = price,
            discounted = discounted,
            product = product,
            onHeaderPositioned = { topPx, heightPx ->
                product.sendVisibility(viewport.shows(topPx, heightPx))
            },
        )

        PrimaryTabRow(
            selectedTabIndex = selectedTab,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
            modifier = Modifier
                .testTag("shopTabs")
                .onGloballyPositioned {
                    tabRowTopPx = (it.positionInWindow().y - viewport.top).toInt() + scrollState.value
                    tabRowHeightPx = it.size.height
                },
        ) {
            listOf("Overview", "Review Details").forEachIndexed { index, title ->
                Tab(
                    selected = selectedTab == index,
                    onClick = {
                        if (selectedTab != index) view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        selectedTab = index
                    },
                    text = { Text(title) },
                )
            }
        }

        if (selectedTab == TAB_REVIEWS) {
            val panelHeightPx = viewportHeightPx - tabRowHeightPx -
                ((PINNED_GAP.value + ITEM_SPACING.value) * density).toInt()
            EmbeddedFlutterView(
                controller = reviews,
                backdropColor = REVIEWS_BACKDROP,
                cornerRadiusDp = 20f,
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .height((panelHeightPx.coerceAtLeast(200 * density.toInt()) / density).dp)
                    .testTag("reviewsPanel")
                    .onGloballyPositioned {
                        reviews.sendVisibility(viewport.shows(it.positionInWindow().y, it.size.height))
                    },
            )
            return@Column
        }

        SectionCard(title = "OPTIONS") {
            SegmentedRow(
                icon = Icons.Filled.Palette,
                title = "Color",
                subtitle = null,
                options = listOf("Midnight", "Silver", "Sky"),
                selectedIndex = color,
                onSelect = { color = it },
            )
            RowDivider()
            ValueRow(icon = Icons.Filled.Inventory2, title = "In the box", subtitle = null, value = "Case, USB-C cable")
        }
        SectionCard(title = "HIGHLIGHTS") {
            InfoRow(Icons.Filled.GraphicEq, "Adaptive noise cancelling", "Tunes itself to your ears 200 times a second")
            RowDivider()
            InfoRow(Icons.Filled.BatteryChargingFull, "38-hour battery", "10 minutes of charging gives 5 hours")
            RowDivider()
            InfoRow(Icons.Filled.SurroundSound, "Spatial audio", "Head tracking for movies and games")
            RowDivider()
            InfoRow(Icons.Filled.Mic, "Six-mic calls", "Beamforming that ignores wind")
            RowDivider()
            InfoRow(Icons.Filled.Eco, "Recycled aluminium", "Frame made from 100% recycled metal")
        }

        InlineFlutterTile(
            controller = promo,
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .fillMaxWidth()
                .height(340.dp)
                .onGloballyPositioned {
                    promo.report(
                        tileTopPx = it.positionInWindow().y,
                        tileHeightPx = it.size.height,
                        viewportTopPx = viewport.top,
                        viewportHeightPx = viewport.height,
                        scrollPx = scrollState.value,
                    )
                },
        )

        SectionCard(title = "SPECIFICATIONS") {
            listOf(
                "Driver" to "40 mm dynamic", "Frequency response" to "4 Hz – 40 kHz",
                "Noise cancelling" to "Hybrid adaptive", "Battery" to "38 h (ANC on)",
                "Charging" to "USB-C, wireless", "Bluetooth" to "5.4, LE Audio",
                "Codecs" to "AAC · LC3 · SBC", "Weight" to "254 g",
                "Microphones" to "6, beamforming", "Water resistance" to "IPX4",
            ).forEachIndexed { index, (name, value) ->
                if (index > 0) RowDivider()
                SpecRow(name, value)
                if (index == 0) {
                    RowDivider()
                    PromoCodeRow(
                        code = promoCode,
                        onCodeChange = {
                            promoCode = it
                            promoRejected = false
                        },
                        applied = discounted,
                        rejected = promoRejected,
                        flash = promoFlash,
                        onApply = ::applyPromoCode,
                    )
                }
            }
        }
        SectionCard(title = "REVIEWS") {
            listOf(
                Triple("Maya R.", 5, "The noise cancelling on a train is unreal."),
                Triple("Tomás", 5, "Comfortable for a full workday."),
                Triple("Priya K.", 4, "Great sound, the case is a little bulky."),
                Triple("Jun", 5, "Battery lasted a whole week of commuting."),
                Triple("Alex", 4, "Calls are clear, even outdoors."),
                Triple("Sam W.", 5, "Spatial audio makes movies feel huge."),
            ).forEachIndexed { index, (name, stars, text) ->
                if (index > 0) RowDivider()
                ReviewRow(name, stars, text)
            }
        }
        SectionCard(title = "SHIPPING & RETURNS") {
            InfoRow(Icons.Filled.LocalShipping, "Free delivery", "Arrives by Friday")
            RowDivider()
            InfoRow(Icons.Filled.Autorenew, "Free returns", "Within 30 days")
            RowDivider()
            InfoRow(Icons.Filled.VerifiedUser, "2-year warranty", "Repairs and replacements")
            RowDivider()
            InfoRow(Icons.Filled.Store, "Pick up in store", "Ready in 2 hours")
        }
        SectionCard(title = "QUESTIONS") {
            listOf(
                "Can I use them with two devices at once?",
                "Do they fold flat for travel?",
                "Is there a wired mode?",
                "How do I update the firmware?",
                "Can I replace the ear cushions?",
            ).forEachIndexed { index, question ->
                if (index > 0) RowDivider()
                DisclosureRow(icon = Icons.AutoMirrored.Filled.HelpOutline, title = question, subtitle = null)
            }
        }

        Text(
            text = "Nimbus One is a demo product. Prices in USD.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
        )
    }
}

@Composable
private fun Hero(
    price: Float,
    discounted: Boolean,
    product: FlutterSurfaceController,
    onHeaderPositioned: (topPx: Float, heightPx: Int) -> Unit,
) {
    Column(modifier = Modifier.padding(16.dp)) {
        // The artwork is the `/product` Flutter view: drag it to orbit.
        EmbeddedFlutterView(
            controller = product,
            backdropColor = HEADER_BACKDROP,
            cornerRadiusDp = 20f,
            modifier = Modifier
                .fillMaxWidth()
                .height(HEADER_HEIGHT)
                .testTag("productHeader")
                .semantics { contentDescription = "Nimbus One in 3D. Drag to rotate." }
                .onGloballyPositioned { onHeaderPositioned(it.positionInWindow().y, it.size.height) },
        )
        Text(
            "Nimbus One",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 16.dp),
        )
        Text(
            "Wireless noise-cancelling headphones",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            "★★★★★  4.7 · 2,184 reviews",
            style = MaterialTheme.typography.labelLarge,
            color = Color(0xFFFF9500),
            modifier = Modifier.padding(top = 4.dp),
        )
        Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(top = 10.dp)) {
            Text(
                String.format(Locale.US, "$%.2f", price),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = if (discounted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
            if (discounted) {
                Text(
                    String.format(Locale.US, "  $%.2f", BASE_PRICE),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textDecoration = TextDecoration.LineThrough,
                )
                Text(
                    "  −20% HOLO20",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

/** A native text field the Flutter badge's callback fills in; see [ShopScreen]. */
@Composable
private fun PromoCodeRow(
    code: String,
    onCodeChange: (String) -> Unit,
    applied: Boolean,
    rejected: Boolean,
    flash: Int,
    onApply: () -> Unit,
) {
    // Briefly tint the field when a code arrives from Flutter, so the
    // audience sees the data land in a native view.
    var highlighted by remember { mutableStateOf(false) }
    LaunchedEffect(flash) {
        if (flash == 0) return@LaunchedEffect
        highlighted = true
        delay(700)
        highlighted = false
    }
    val container by animateColorAsState(
        targetValue = if (highlighted) {
            MaterialTheme.colorScheme.primary.copy(alpha = 0.22f)
        } else {
            MaterialTheme.colorScheme.surfaceContainerHighest
        },
        label = "promoHighlight",
    )
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Icon(Icons.Filled.LocalOffer, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        TextField(
            value = code,
            onValueChange = onCodeChange,
            placeholder = { Text("Promo code") },
            singleLine = true,
            // Read-only rather than disabled once applied: a disabled field is
            // greyed out, and the code is exactly what the audience should see.
            readOnly = applied,
            isError = rejected,
            trailingIcon = if (applied) {
                { Icon(Icons.Filled.CheckCircle, contentDescription = "Applied", tint = MaterialTheme.colorScheme.primary) }
            } else {
                null
            },
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                color = if (applied) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            ),
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Characters,
                autoCorrectEnabled = false,
                imeAction = ImeAction.Done,
            ),
            keyboardActions = KeyboardActions(onDone = { onApply() }),
            shape = RoundedCornerShape(10.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = container,
                unfocusedContainerColor = container,
                disabledContainerColor = container,
                errorContainerColor = container,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                disabledIndicatorColor = Color.Transparent,
            ),
            modifier = Modifier
                .weight(1f)
                .testTag("promoCodeField"),
        )
        FilledTonalButton(onClick = onApply, enabled = !applied) {
            Text(if (applied) "Applied" else "Apply")
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, title: String, subtitle: String) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = { Text(subtitle) },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        colors = rowColors(),
    )
}

@Composable
private fun SpecRow(name: String, value: String) {
    ListItem(
        headlineContent = { Text(name) },
        trailingContent = {
            Text(value, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        colors = rowColors(),
    )
}

@Composable
private fun ReviewRow(name: String, stars: Int, text: String) {
    ListItem(
        overlineContent = { Text("${"★".repeat(stars)}${"☆".repeat(5 - stars)}  $name", color = Color(0xFFFF9500)) },
        headlineContent = { Text(text) },
        colors = rowColors(),
    )
}

private fun View.confirmHaptic() {
    val feedback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        HapticFeedbackConstants.CONFIRM
    } else {
        HapticFeedbackConstants.VIRTUAL_KEY
    }
    performHapticFeedback(feedback)
}
