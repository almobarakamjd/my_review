package com.example.my_review // تأكد أن هذا السطر يطابق الباكيج نيم الخاص بك

import android.app.ActivityManager
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.my_review/lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startLock") {
                // تفعيل وضع القفل (إخفاء الأزرار)
                startLockTask()
                result.success(true)
            } else if (call.method == "stopLock") {
                // إلغاء وضع القفل (إظهار الأزرار)
                try {
                    stopLockTask()
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}