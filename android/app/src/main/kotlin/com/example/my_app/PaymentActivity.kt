package com.example.my_app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient

class PaymentActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val url = intent.getStringExtra("url") ?: return finish()
        val webView = WebView(this)
        webView.settings.javaScriptEnabled = true
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                if (uri.scheme == "mealmind" && uri.host == "payment") {
                    setResult(RESULT_OK, Intent().putExtra("paid", uri.getQueryParameter("status") == "paid"))
                    finish()
                    return true
                }
                return false
            }
        }
        setContentView(webView)
        webView.loadUrl(url)
    }
}
