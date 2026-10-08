package com.example.my_app

import android.content.Intent
import android.net.Uri
import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var paymentResult: MethodChannel.Result? = null
    private var avatarResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mealmind/browser")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.arguments as? String
                val uri = url?.let(Uri::parse)
                if (uri == null || uri.scheme != "https") {
                    result.success(false)
                    return@setMethodCallHandler
                }
                paymentResult = result
                startActivityForResult(Intent(this, PaymentActivity::class.java).putExtra("url", url), 701)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mealmind/avatar")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") return@setMethodCallHandler result.notImplemented()
                avatarResult = result
                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }, 702)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 701) {
            paymentResult?.success(resultCode == Activity.RESULT_OK && data?.getBooleanExtra("paid", false) == true)
            paymentResult = null
        } else if (requestCode == 702) {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) avatarResult?.success(null) else try {
                val bitmap = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
                val scale = minOf(1.0, 512.0 / maxOf(bitmap.width, bitmap.height))
                val resized = Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
                val bytes = ByteArrayOutputStream().also { resized.compress(Bitmap.CompressFormat.JPEG, 82, it) }.toByteArray()
                avatarResult?.success("data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP))
            } catch (_: Exception) { avatarResult?.error("avatar", "無法讀取圖片", null) }
            avatarResult = null
        }
    }
}
