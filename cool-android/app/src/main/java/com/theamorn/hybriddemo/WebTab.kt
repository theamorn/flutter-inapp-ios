package com.theamorn.hybriddemo

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Tab 2: The native Android Web tab.
 *
 * Hosts an [android.webkit.WebView] displaying the bundled `settings.html` offline
 * page, mirroring `cool-ios/cool-ios/SettingsWebViewController.swift`.
 *
 * It provides:
 * 1. Self-contained offline execution: only `file:///android_asset/settings.html`
 *    and internal hash anchors are allowed; external network navigation is blocked.
 * 2. Lifecycle synchronization: calls `window.setDemoActive(active)` in JS so the
 *    artificial stress test loop is suspended when this tab is not visible.
 * 3. Window insets handling: pads top by the status bar height so the sticky top bar
 *    sits cleanly below system status bar icons.
 */
@SuppressLint("SetJavaScriptEnabled")
class WebTab(context: Context) : FrameLayout(context) {

    private val webView: WebView = WebView(context).apply {
        layoutParams = LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        setBackgroundColor(Color.TRANSPARENT)
        isVerticalScrollBarEnabled = true
        isHorizontalScrollBarEnabled = false

        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            displayZoomControls = false
            builtInZoomControls = false
            setSupportZoom(false)
        }

        webChromeClient = WebChromeClient()
        webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url
                // Only permit the bundled local asset and internal fragment anchors.
                if (url.scheme == "file" && (url.path?.endsWith("settings.html") == true || url.path == null)) {
                    return false
                }
                return true // cancel external or unexpected navigation
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                updatePageActive()
            }
        }
    }

    private var pageActive = false

    init {
        addView(webView)

        // Ensure the web page's sticky header clears the Android status bar.
        ViewCompat.setOnApplyWindowInsetsListener(this) { view, insets ->
            val statusBars = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            view.setPadding(0, statusBars.top, 0, 0)
            insets
        }

        webView.loadUrl("file:///android_asset/settings.html")
    }

    /**
     * Informs the bundled web page whether this tab is currently visible.
     * When hidden, the web page pauses its RAF and stress simulation loops.
     */
    fun setPageActive(active: Boolean) {
        if (pageActive == active) return
        pageActive = active
        updatePageActive()
    }

    private fun updatePageActive() {
        webView.evaluateJavascript("window.setDemoActive?.($pageActive);", null)
    }

    fun onDestroy() {
        webView.destroy()
    }
}
