package com.routeflux.vpn

import android.app.*
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.InetAddress

class MyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var tun2socksPid: Int? = null
    private var running = false

    init {
        System.loadLibrary("native_utils")
    }

    private external fun startProcessNative(
        executable: String, fdArg: String, proxy: String, fd: Int, logPath: String
    ): Int

    companion object {
        private const val TAG = "RouteFlux"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "routeflux_vpn_channel"

        var statusListener: ((String) -> Unit)? = null

        fun start(context: Context, proxy: String?) {
            val intent = Intent(context, MyVpnService::class.java)
            intent.putExtra("PROXY_URL", proxy)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, MyVpnService::class.java)
            intent.action = "STOP"
            context.startService(intent)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val proxy = intent?.getStringExtra("PROXY_URL")

        startForeground(NOTIFICATION_ID, buildNotification("Initializing..."))

        if (intent?.action == "STOP") {
            Log.i(TAG, "Received STOP command")
            stopVpnInternal()
            statusListener?.invoke("disconnected")
            stopSelf()
            return START_NOT_STICKY
        }

        if (proxy != null) {
            if (running) {
                Log.i(TAG, "Restarting VPN with new proxy")
                stopVpnInternal()
            }
            // Run on background thread — DNS resolution is a network operation
            Thread { startVpn(proxy) }.start()
        } else {
            if (!running) {
                Log.e(TAG, "Service started without proxy URL, stopping")
                statusListener?.invoke("error:No proxy URL provided")
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    private fun startVpn(proxy: String) {
        running = true
        updateNotification("Resolving proxy...")

        // ── Step 1: Resolve proxy hostname to IP ────────────────────────
        var proxyIp = ""
        try {
            val uri = java.net.URI(proxy)
            val host = uri.host ?: ""
            if (host.isNotEmpty()) {
                val resolved = InetAddress.getByName(host)
                proxyIp = resolved.hostAddress ?: host
                Log.i(TAG, "Resolved proxy hostname '$host' to IP '$proxyIp'")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve proxy hostname", e)
            statusListener?.invoke("error:Failed to resolve proxy: ${e.message}")
            running = false
            stopSelf()
            return
        }

        updateNotification("Connecting...")

        // ── Step 2: Build VPN interface ─────────────────────────────────
        val builder = Builder()
            .setSession("RouteFlux VPN")
            .setMtu(1500)
            .addAddress("10.0.0.2", 32)
            .addDnsServer("8.8.8.8")
            .addDnsServer("8.8.4.4")

        // ── Step 3: Routes — exclude ONLY the proxy server IP ───────────
        // DNS IPs are NOT excluded so DNS queries route through VPN (no leak)
        try {
            if (proxyIp.isNotEmpty()) {
                val allowedRoutes = calculateRoutesExcluding(listOf(proxyIp))
                for (route in allowedRoutes) {
                    builder.addRoute(route.address, route.prefix)
                }
                Log.i(TAG, "Configured ${allowedRoutes.size} routes, excluding proxy IP: $proxyIp")
            } else {
                builder.addRoute("0.0.0.0", 0)
                Log.w(TAG, "No proxy IP to exclude, routing all traffic through VPN")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to calculate exclusion routes, using fallback", e)
            builder.addRoute("0.0.0.0", 0)
        }

        // Exclude this app from VPN to prevent routing loop on proxy socket
        builder.addDisallowedApplication(packageName)

        vpnInterface = builder.establish()

        if (vpnInterface == null) {
            Log.e(TAG, "Failed to establish VPN Interface")
            statusListener?.invoke("error:Failed to establish VPN interface")
            running = false
            stopSelf()
            return
        }

        Log.i(TAG, "VPN Interface established. FD: ${vpnInterface?.fileDescriptor}")

        // Kill previous tun2socks process if still alive
        if (tun2socksPid != null) {
            android.os.Process.killProcess(tun2socksPid!!)
            tun2socksPid = null
        }

        startTun2Socks(proxy)
    }

    // ── tun2socks process management ────────────────────────────────────

    private fun startTun2Socks(proxy: String) {
        val fd = vpnInterface!!.getFd()
        val tun2socksPath = extractTun2Socks()

        if (tun2socksPath == null) {
            Log.e(TAG, "Failed to find tun2socks binary")
            statusListener?.invoke("error:tun2socks binary not found")
            running = false
            stopSelf()
            return
        }

        Thread {
            try {
                Log.i(TAG, "Starting tun2socks via JNI...")

                val logFile = File(applicationContext.filesDir, "vpn_log.txt")
                if (!logFile.exists()) logFile.createNewFile()
                val logPath = logFile.absolutePath

                val pid = startProcessNative(tun2socksPath, "fd://$fd", proxy, fd, logPath)

                if (pid > 0) {
                    tun2socksPid = pid
                    Log.i(TAG, "tun2socks started with PID: $pid")
                    updateNotification("Connected — traffic secured")
                    statusListener?.invoke("connected")
                } else {
                    Log.e(TAG, "Failed to start tun2socks process")
                    statusListener?.invoke("error:Failed to start tun2socks")
                    running = false
                    stopSelf()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start tun2socks", e)
                statusListener?.invoke("error:${e.message}")
                running = false
                stopSelf()
            }
        }.start()

        // Log watcher thread — pipes tun2socks file logs to Logcat
        Thread {
            try {
                val logFile = File(applicationContext.filesDir, "vpn_log.txt")
                var attempts = 0
                while (!logFile.exists() && attempts < 20) {
                    Thread.sleep(100)
                    attempts++
                }

                if (logFile.exists()) {
                    val reader = java.io.BufferedReader(java.io.FileReader(logFile))
                    var line: String?
                    while (running) {
                        line = reader.readLine()
                        if (line != null) {
                            Log.i("TUN2SOCKS", line)
                        } else {
                            Thread.sleep(200)
                        }
                    }
                    reader.close()
                }
            } catch (e: Exception) {
                Log.e("TUN2SOCKS", "Log watcher failed", e)
            }
        }.start()
    }

    private fun extractTun2Socks(): String? {
        return try {
            val libPath = applicationContext.applicationInfo.nativeLibraryDir + "/libtun2socks.so"
            val file = File(libPath)
            if (file.exists()) libPath
            else {
                Log.e(TAG, "Native library not found at $libPath")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding native library", e)
            null
        }
    }

    // ── Lifecycle & cleanup ─────────────────────────────────────────────

    override fun onDestroy() {
        stopVpnInternal()
        super.onDestroy()
    }

    private fun stopVpnInternal() {
        running = false

        if (tun2socksPid != null) {
            try {
                android.os.Process.killProcess(tun2socksPid!!)
                Log.i(TAG, "Killed tun2socks PID: $tun2socksPid")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to kill tun2socks process", e)
            }
        }
        tun2socksPid = null

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null
        stopForeground(true)
    }

    // ── Notifications ───────────────────────────────────────────────────

    private fun updateNotification(status: String) {
        try {
            val nm = getSystemService(NotificationManager::class.java)
            nm?.notify(NOTIFICATION_ID, buildNotification(status))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }

    private fun buildNotification(status: String): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RouteFlux VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
            }
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RouteFlux VPN")
            .setContentText(status)
            .setSmallIcon(R.drawable.ic_vpn_notification)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    // ── Route calculation (CIDR splitting to exclude specific IPs) ──────

    data class Cidr(val address: String, val prefix: Int)

    private fun calculateRoutesExcluding(ipsToExclude: List<String>): List<Cidr> {
        var routes = listOf(Cidr("0.0.0.0", 0))

        for (ip in ipsToExclude) {
            if (ip.isEmpty()) continue
            val newRoutes = ArrayList<Cidr>()
            val target = ipToLong(ip)

            for (route in routes) {
                if (cidrContains(route, target)) {
                    newRoutes.addAll(splitCidrAround(route, target))
                } else {
                    newRoutes.add(route)
                }
            }
            routes = newRoutes
        }
        return routes
    }

    private fun cidrContains(cidr: Cidr, ip: Long): Boolean {
        val cidrBase = ipToLong(cidr.address)
        val mask = if (cidr.prefix == 0) 0L else -1L shl (32 - cidr.prefix)
        return (cidrBase and mask) == (ip and mask)
    }

    private fun splitCidrAround(cidr: Cidr, targetIp: Long): List<Cidr> {
        val splits = ArrayList<Cidr>()
        var base = ipToLong(cidr.address)

        for (p in cidr.prefix until 32) {
            val step = 1L shl (31 - p)
            val nextPrefix = p + 1
            val bitVal = (targetIp shr (31 - p)) and 1

            if (bitVal == 0L) {
                splits.add(longToCidr(base + step, nextPrefix))
            } else {
                splits.add(longToCidr(base, nextPrefix))
                base += step
            }
        }
        return splits
    }

    private fun ipToLong(ip: String): Long {
        val parts = ip.split(".")
        if (parts.size != 4) return 0L
        var result = 0L
        for (part in parts) {
            result = (result shl 8) + (part.toIntOrNull() ?: 0)
        }
        return result
    }

    private fun longToCidr(ip: Long, prefix: Int): Cidr {
        val sb = StringBuilder()
        sb.append((ip shr 24) and 0xFF).append(".")
        sb.append((ip shr 16) and 0xFF).append(".")
        sb.append((ip shr 8) and 0xFF).append(".")
        sb.append(ip and 0xFF)
        return Cidr(sb.toString(), prefix)
    }
}
