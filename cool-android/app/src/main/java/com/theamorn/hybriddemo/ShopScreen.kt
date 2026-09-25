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
import androidx.compose.material.icons.filled.Headphones
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
import androidx.compose.material3.Scaffold
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
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

/**
 * Tab 4 on Android: a Material 3 product page with the `/promo` Flutter tile
 * halfway down, mirroring `cool-ios/cool-ios/ProductDetailViewController.swift`
 * section for section.
 *
 * Compose owns everything around the tile: layout, scrolling, the price, and
 * the success haptic. Flutter draws the badge and, when it is tapped, hands
 * back the promo code; this page fills its own native promo field with it,
 * validates it, and reprices.
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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceContainerLowest)
            .padding(contentPadding)
            .onGloballyPositioned {
                viewport.top = it.positionInWindow().y
                viewport.height = it.size.height
            }
            .verticalScroll(scrollState)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Hero(price = price, discounted = discounted)

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
private fun Hero(price: Float, discounted: Boolean) {
    Column(modifier = Modifier.padding(16.dp)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Brush.linearGradient(listOf(Color(0xFF5856D6), Color(0xFFAF52DE)))),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Headphones, contentDescription = null, tint = Color.White, modifier = Modifier.size(120.dp))
        }
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
