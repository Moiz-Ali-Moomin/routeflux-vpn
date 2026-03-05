package com.routeflux.vpn

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "vpn"
    private val EVENT_CHANNEL = "vpn_status"
    private val VPN_REQUEST_CODE = 24
    private val NOTIFICATION_PERMISSION_CODE = 25

    private fun getProxyFile(): java.io.File {
        return java.io.File(filesDir, "pending_proxy.txt")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request notification permission on Android 13+
        requestNotificationPermission()

        // ── Method Channel: commands from Flutter ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "prepareVpn" -> {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }

                    "startVpn" -> {
                        val proxy = call.argument<String>("proxy")
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            // VPN not yet prepared — save proxy and show permission dialog
                            try {
                                getProxyFile().writeText(proxy ?: "")
                                Log.i("RouteFlux", "Proxy saved, requesting VPN permission")
                            } catch (e: Exception) {
                                Log.e("RouteFlux", "Failed to save proxy to file", e)
                            }
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            // VPN already prepared — start service directly
                            Log.i("RouteFlux", "VPN prepared, starting service with proxy: $proxy")
                            MyVpnService.start(this, proxy)
                        }
                        result.success(null)
                    }

                    "stopVpn" -> {
                        MyVpnService.stop(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Event Channel: VPN status updates to Flutter ────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    MyVpnService.statusListener = { status ->
                        runOnUiThread { events?.success(status) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    MyVpnService.statusListener = null
                }
            })
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == VPN_REQUEST_CODE && resultCode == Activity.RESULT_OK) {
            val file = getProxyFile()
            var proxy: String? = null
            if (file.exists()) {
                proxy = file.readText()
            }

            if (proxy.isNullOrEmpty()) {
                Log.e("RouteFlux", "Failed to retrieve proxy from file after permission grant")
                MyVpnService.statusListener?.invoke("error:Failed to retrieve proxy configuration")
            } else {
                Log.i("RouteFlux", "VPN permission granted. Starting service with proxy: $proxy")
                MyVpnService.start(this, proxy)
            }
        } else if (requestCode == VPN_REQUEST_CODE) {
            Log.e("RouteFlux", "VPN permission denied. ResultCode: $resultCode")
            MyVpnService.statusListener?.invoke("error:VPN permission denied")
        }
    }
}
