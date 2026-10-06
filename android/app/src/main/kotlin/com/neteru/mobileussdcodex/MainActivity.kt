package com.neteru.mobileussdcodex

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.database.sqlite.SQLiteDatabase
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingContactPick: MethodChannel.Result? = null
    private var channel: MethodChannel? = null

    /** Code a shortcut opened the app on, until Dart takes it. */
    private var launchCodeId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        launchCodeId = intent?.getStringExtra(EXTRA_CODE_ID)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ussd_codes/telephony")
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimOperators" -> result.success(simOperators())
                "getNetworkCountries" -> result.success(networkCountries())
                "dial" -> result.success(dial(call.argument<String>("code")!!, call.argument<Boolean>("direct") ?: false))
                "readLegacyData" -> result.success(readLegacyData())
                "requestReview" -> requestReview { shown -> result.success(shown) }
                "pickPhoneNumber" -> pickPhoneNumber(result)
                "sendUssd" -> sendUssd(call.argument<String>("code")!!) { response -> result.success(response) }
                "takeLaunchCodeId" -> result.success(launchCodeId).also { launchCodeId = null }
                "setShortcuts" -> result.success(setShortcuts(call.argument<List<Map<String, String>>>("codes")!!))
                "pinShortcut" -> result.success(pinShortcut(call.argument<String>("id")!!, call.argument<String>("label")!!))
                else -> result.notImplemented()
            }
        }
    }

    // A shortcut tapped while the app runs (singleTop): open its code now.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(EXTRA_CODE_ID)?.let { channel?.invokeMethod("openCode", it) }
    }

    private fun shortcut(id: String, label: String): ShortcutInfo =
        ShortcutInfo.Builder(this, "code:$id")
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(Icon.createWithResource(this, R.drawable.ic_shortcut_code))
            .setIntent(
                Intent(this, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .putExtra(EXTRA_CODE_ID, id)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            )
            .build()

    /**
     * The shortcuts shown on a long press on the app icon (Android 7.1+):
     * [codes] are maps with "id" and "label". Returns whether they were set.
     */
    private fun setShortcuts(codes: List<Map<String, String>>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        val shortcuts = codes.take(manager.maxShortcutCountPerActivity).map { shortcut(it["id"]!!, it["label"]!!) }
        return try {
            manager.setDynamicShortcuts(shortcuts)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Asks the launcher to pin a shortcut to the code on the home screen
     * (Android 8+); the launcher confirms with the user. Returns false when
     * the launcher doesn't support it.
     */
    private fun pinShortcut(id: String, label: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false
        return try {
            manager.requestPinShortcut(shortcut(id, label), null)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Opens the system contact picker, restricted to phone numbers. The picker
     * grants read access to the chosen entry only, so the app needs no
     * READ_CONTACTS permission. Answers the number, or null when cancelled.
     */
    private fun pickPhoneNumber(result: MethodChannel.Result) {
        pendingContactPick?.success(null)
        pendingContactPick = result
        try {
            startActivityForResult(Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI), PICK_PHONE_NUMBER)
        } catch (e: ActivityNotFoundException) {
            pendingContactPick = null
            result.success(null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_PHONE_NUMBER) return
        val result = pendingContactPick ?: return
        pendingContactPick = null

        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val number = try {
            contentResolver.query(uri, arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
        result.success(number)
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
     * ISO codes (lowercase) of the countries of the networks the phone is
     * registered on, voice SIM first: where the user is, even when roaming.
     * Needs no permission; empty without signal or in airplane mode.
     */
    private fun networkCountries(): List<String> {
        val telephony = getSystemService(TelephonyManager::class.java) ?: return emptyList()
        val subscriptionIds = listOf(
            SubscriptionManager.getDefaultVoiceSubscriptionId(),
            SubscriptionManager.getDefaultDataSubscriptionId(),
        ).filter { it != SubscriptionManager.INVALID_SUBSCRIPTION_ID }.distinct()

        val countries = subscriptionIds.map { telephony.createForSubscriptionId(it).networkCountryIso } + telephony.networkCountryIso
        return countries.filter { !it.isNullOrEmpty() }.map { it.lowercase() }.distinct()
    }

    /**
     * Runs [code] in the background and answers the network's response, so
     * the app can show it (Android 8+, CALL_PHONE granted). Answers
     * {"response": text} or {"failure": "unsupported" | "denied" | "failed"}.
     * The response can't be answered: a code opening a menu has to be
     * continued in the dialer.
     */
    private fun sendUssd(code: String, done: (Map<String, Any?>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return done(mapOf("failure" to "unsupported"))
        if (checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            return done(mapOf("failure" to "denied"))
        }
        val telephony = getSystemService(TelephonyManager::class.java) ?: return done(mapOf("failure" to "unsupported"))
        val callback = object : TelephonyManager.UssdResponseCallback() {
            override fun onReceiveUssdResponse(telephonyManager: TelephonyManager, request: String, response: CharSequence) {
                done(mapOf("response" to response.toString()))
            }

            override fun onReceiveUssdResponseFailed(telephonyManager: TelephonyManager, request: String, failureCode: Int) {
                done(mapOf("failure" to "failed"))
            }
        }
        try {
            telephony.sendUssdRequest(code, callback, Handler(Looper.getMainLooper()))
        } catch (e: SecurityException) {
            done(mapOf("failure" to "denied"))
        } catch (e: Exception) {
            done(mapOf("failure" to "failed"))
        }
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

    private companion object {
        const val PICK_PHONE_NUMBER = 4201
        const val EXTRA_CODE_ID = "codeId"
    }
}
