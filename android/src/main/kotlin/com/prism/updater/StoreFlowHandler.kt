package com.prism.updater

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel

/**
 * Opens the Play Store page for the running application via the market://
 * intent, falling back to the https:// play URL when the store app is
 * missing. This is the real native store flow — no browser hop.
 */
object StoreFlowHandler {
    private const val CHANNEL = "prism_updater/store_flow"

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchStore" -> result.success(launch())
                else -> result.notImplemented()
            }
        }
    }

    private fun launch(): String {
        val context = AppContextHolder.context ?: return "unavailable"
        val packageName = context.packageName
        val marketUri = Uri.parse("market://details?id=$packageName")
        val webUri = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
        return try {
            context.startActivity(Intent(Intent.ACTION_VIEW, marketUri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            "launched"
        } catch (e: ActivityNotFoundException) {
            try {
                context.startActivity(Intent(Intent.ACTION_VIEW, webUri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                "launched"
            } catch (e2: ActivityNotFoundException) {
                "failed"
            }
        } catch (e: SecurityException) {
            "failed"
        }
    }
}

/** Holds the application context, set from the plugin registration. */
object AppContextHolder {
    @JvmStatic
    var context: android.content.Context? = null
}
