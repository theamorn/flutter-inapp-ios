package com.theamorn.hybriddemo

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Backup
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Feedback
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * The native Android Home tab.
 *
 * This mirrors `cool-ios/cool-ios/HomeViewController.swift` section for section
 * and row for row — profile header, YOUR WEEK, PREFERENCES, ACCOUNT, RECENT
 * ACTIVITY, SUPPORT, sign out — using Material 3 components rather than UIKit's.
 *
 * The point on stage is precise: the layout is the same, the components are
 * visibly different, and both are genuinely native to their platform. That is
 * the whole reason tab 1 is not built in Flutter. So do not "improve" the
 * information architecture here without changing iOS to match; the parity photo
 * is the deliverable.
 */
@Composable
fun HomeScreen(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(0.dp),
) {
    var notifications by remember { mutableStateOf(true) }
    var haptics by remember { mutableStateOf(true) }
    var focusMode by remember { mutableIntStateOf(1) }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceContainerLowest),
        contentPadding = contentPadding,
    ) {
        item { ProfileHeader() }

        item {
            SectionCard(title = "YOUR WEEK") {
                WeeklySummaryRow()
                RowDivider()
                DisclosureRow(
                    icon = Icons.AutoMirrored.Filled.TrendingUp,
                    title = "Activity snapshot",
                    subtitle = "You completed 12 tasks this week",
                )
                RowDivider()
                ValueRow(
                    icon = Icons.Filled.SportsEsports,
                    title = "Highest Score: ${GameScoreManager.highestScore}",
                    subtitle = "Flappy Cat",
                    value = "${GameScoreManager.highestScore}",
                )
                RowDivider()
                QuickActionsRow()
            }
        }

        item {
            SectionCard(
                title = "PREFERENCES",
                footer = "Focus mode only changes how your dashboard is organized.",
            ) {
                ToggleRow(
                    icon = Icons.Filled.Notifications,
                    title = "Notifications",
                    subtitle = "Reminders and important updates",
                    checked = notifications,
                    onCheckedChange = { notifications = it },
                )
                RowDivider()
                SegmentedRow(
                    icon = Icons.Filled.TrackChanges,
                    title = "Focus mode",
                    subtitle = "Choose what appears first",
                    options = listOf("Off", "Work", "Life"),
                    selectedIndex = focusMode,
                    onSelect = { focusMode = it },
                )
                RowDivider()
                ToggleRow(
                    icon = Icons.Filled.PhoneAndroid,
                    title = "Haptic feedback",
                    subtitle = "Use subtle feedback for actions",
                    checked = haptics,
                    onCheckedChange = { haptics = it },
                )
            }
        }

        item {
            SectionCard(title = "ACCOUNT") {
                DisclosureRow(Icons.Filled.AccountCircle, "Personal information", "Name, email, and profile photo")
                RowDivider()
                DisclosureRow(Icons.Filled.Security, "Privacy & security", "Fingerprint, screen lock, and permissions")
                RowDivider()
                DisclosureRow(Icons.Filled.CreditCard, "Payment methods", "Visa ending in 4242")
                RowDivider()
                ValueRow(Icons.Filled.Devices, "Connected devices", "2 active devices", "2")
                RowDivider()
                ValueRow(Icons.Filled.Storage, "Data & storage", "Manage downloads and cache", "1.8 GB")
            }
        }

        item {
            SectionCard(
                title = "RECENT ACTIVITY",
                footer = "Activity is stored securely for 30 days.",
            ) {
                DisclosureRow(Icons.Filled.CheckCircle, "Weekly plan completed", "Today at 9:42 AM")
                RowDivider()
                DisclosureRow(Icons.Filled.Autorenew, "Subscription renewed", "Yesterday")
                RowDivider()
                DisclosureRow(Icons.Filled.PhoneAndroid, "Signed in on Pixel", "Monday at 4:18 PM")
                RowDivider()
                DisclosureRow(Icons.Filled.Backup, "Cloud backup finished", "Sunday at 11:06 PM")
            }
        }

        item {
            SectionCard(
                title = "SUPPORT",
                footer = "Hybrid Demo 1.0 (Build 42)",
            ) {
                DisclosureRow(Icons.AutoMirrored.Filled.HelpOutline, "Help center", "Guides and frequently asked questions")
                RowDivider()
                DisclosureRow(Icons.Filled.AutoAwesome, "What's new", "See the latest improvements")
                RowDivider()
                DisclosureRow(Icons.Filled.Feedback, "Send feedback", "Tell us what could be better")
                RowDivider()
                DisclosureRow(Icons.Filled.Info, "About", "Licenses, policies, and acknowledgements")
            }
        }

        item {
            OutlinedButton(
                onClick = {},
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp)
                    .height(48.dp),
            ) {
                Text("Sign Out", color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
            }
        }

        item { Spacer(Modifier.height(12.dp)) }
    }
}

@Composable
private fun ProfileHeader() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(68.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "AD",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 16.dp),
            ) {
                Text("Avery Davis", style = MaterialTheme.typography.titleLarge)
                Text(
                    "Product designer · Bangkok",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 3.dp),
                )
                Box(
                    modifier = Modifier
                        .padding(top = 9.dp)
                        .background(AvailableGreen.copy(alpha = 0.14f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                ) {
                    Text(
                        "●  Available",
                        style = MaterialTheme.typography.labelMedium,
                        color = AvailableGreen,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            FilledTonalButton(
                onClick = {},
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                modifier = Modifier.height(36.dp),
            ) {
                Text("Edit", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
internal fun SectionCard(
    title: String,
    footer: String? = null,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 4.dp, top = 12.dp, bottom = 6.dp),
        )
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        ) {
            Column { content() }
        }
        if (footer != null) {
            Text(
                text = footer,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp),
            )
        }
    }
}

@Composable
internal fun RowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 56.dp),
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}

@Composable
internal fun rowColors() = ListItemDefaults.colors(containerColor = Color.Transparent)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DisclosureRow(icon: ImageVector, title: String, subtitle: String?) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = subtitle?.let { { Text(it) } },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        colors = rowColors(),
        modifier = Modifier.clickable {},
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ValueRow(icon: ImageVector, title: String, subtitle: String?, value: String) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = subtitle?.let { { Text(it) } },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = {
            Text(
                value,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        colors = rowColors(),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ToggleRow(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = subtitle?.let { { Text(it) } },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = { Switch(checked = checked, onCheckedChange = onCheckedChange) },
        colors = rowColors(),
    )
}

@Composable
internal fun SegmentedRow(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
) {
    Row(modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 12.dp)) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(top = 2.dp),
        )
        Column(modifier = Modifier.padding(start = 16.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            SingleChoiceSegmentedButtonRow(modifier = Modifier.padding(top = 8.dp)) {
                options.forEachIndexed { index, label ->
                    SegmentedButton(
                        selected = index == selectedIndex,
                        onClick = { onSelect(index) },
                        shape = SegmentedButtonDefaults.itemShape(index, options.size),
                    ) {
                        Text(label)
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklySummaryRow() {
    val metrics = listOf(
        Triple("12", "Tasks", Icons.Filled.CheckCircle),
        Triple("5", "Day streak", Icons.Filled.LocalFireDepartment),
        Triple("8.4h", "Focused", Icons.Filled.Timer),
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        metrics.forEachIndexed { index, (value, label, icon) ->
            if (index > 0) {
                VerticalDivider(
                    modifier = Modifier.height(56.dp),
                    color = MaterialTheme.colorScheme.outlineVariant,
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    value,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 5.dp),
                )
                Text(
                    label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun QuickActionsRow() {
    val actions = listOf(
        "Add task" to Icons.Filled.Add,
        "Scan" to Icons.Filled.QrCodeScanner,
        "Share" to Icons.Filled.Share,
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        actions.forEach { (label, icon) ->
            FilledTonalButton(
                onClick = {},
                modifier = Modifier
                    .weight(1f)
                    .height(64.dp),
                shape = RoundedCornerShape(12.dp),
                contentPadding = PaddingValues(4.dp),
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.height(6.dp))
                    Text(label, style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
    Spacer(Modifier.width(0.dp))
}

private val AvailableGreen = Color(0xFF2E7D32)
