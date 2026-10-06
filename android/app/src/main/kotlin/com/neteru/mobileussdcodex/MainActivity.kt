package com.neteru.mobileussdcodex

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ussd_codes/telephony").setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimOperators" -> result.success(simOperators())
                "dial" -> result.success(dial(call.argument<String>("code")!!, call.argument<Boolean>("direct") ?: false))
                "readLegacyData" -> result.success(readLegacyData())
                "requestReview" -> requestReview { shown -> result.success(shown) }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Opens the Play In-App Review flow. Play decides whether the dialog
     * actually shows (quota), so "done" only means the flow ran.
     */
    private fun requestReview(done: (Boolean) -> Unit) {
        val manager = ReviewManagerFactory.create(this)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful) {
                done(false)
                return@addOnCompleteListener
            }
            manager.launchReviewFlow(this, request.result).addOnCompleteListener { done(true) }
        }
    }

    /**
     * MCC+MNC of the SIM cards set as default for voice, data and SMS, without
     * the READ_PHONE_STATE permission that listing every subscription needs:
     * on a dual-SIM phone, these usually cover both SIMs.
     */
    private fun simOperators(): List<String> {
        val telephony = getSystemService(TelephonyManager::class.java) ?: return emptyList()
        val subscriptionIds = listOf(
            SubscriptionManager.getDefaultVoiceSubscriptionId(),
            SubscriptionManager.getDefaultDataSubscriptionId(),
            SubscriptionManager.getDefaultSmsSubscriptionId(),
        ).filter { it != SubscriptionManager.INVALID_SUBSCRIPTION_ID }.distinct()

        val operators = subscriptionIds.map { telephony.createForSubscriptionId(it).simOperator } + telephony.simOperator
        return operators.filter { !it.isNullOrEmpty() && it.length >= 5 }.distinct()
    }

    /**
     * Calls [code] directly when asked and allowed (CALL_PHONE granted),
     * otherwise opens the dialer with the code typed in, which needs no
     * permission. Returns "called", "dialerOpened" or "failed".
     */
    private fun dial(code: String, direct: Boolean): String {
        // Uri.encode keeps "*" and escapes "#", which a tel: URI would otherwise
        // treat as a fragment.
        val uri = Uri.parse("tel:" + Uri.encode(code))
        val canCall = direct && checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
        return try {
            startActivity(Intent(if (canCall) Intent.ACTION_CALL else Intent.ACTION_DIAL, uri))
            if (canCall) "called" else "dialerOpened"
        } catch (e: ActivityNotFoundException) {
            "failed"
        } catch (e: SecurityException) {
            "failed"
        }
    }

    /**
     * Favorites, personal codes and default country saved by the legacy
     * Java app (same application id), so an update keeps them. Null when the
     * legacy app was never installed.
     */
    private fun readLegacyData(): Map<String, Any?>? {
        val dbFile = getDatabasePath("Mucx.db")
        if (!dbFile.exists()) return null

        val codes = mutableListOf<Map<String, Any?>>()
        try {
            SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT description, code, fragment, isNative, isFavorite FROM ussd", null).use { cursor ->
                    while (cursor.moveToNext()) {
                        val isNative = cursor.getString(3).isTrue()
                        val isFavorite = cursor.getString(4).isTrue()
                        // Native codes come from the catalog: only favorites matter.
                        if (isNative && !isFavorite) continue
                        codes.add(
                            mapOf(
                                "description" to cursor.getString(0),
                                "code" to cursor.getString(1),
                                "fragment" to cursor.getString(2),
                                "isNative" to isNative,
                                "isFavorite" to isFavorite,
                            ),
                        )
                    }
                }
            }
        } catch (e: Exception) {
            return null
        }

        val country = getSharedPreferences("${packageName}_preferences", MODE_PRIVATE).getString("currentCountry", null)
        return mapOf("codes" to codes, "country" to country)
    }

    // ORMLite stores booleans as 0/1 on Android; accept "true" too, just in case.
    private fun String?.isTrue() = this == "1" || this.equals("true", ignoreCase = true)
}
