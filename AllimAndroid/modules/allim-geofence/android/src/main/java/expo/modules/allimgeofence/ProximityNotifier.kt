package expo.modules.allimgeofence

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Decides whether arriving at a store is worth a notification, and posts it.
 * Port of the iOS LocationMonitoringManager.handleStoreProximity and
 * NotificationManager.scheduleStoreProximityNotification.
 *
 * Runs on a background thread inside a geofence broadcast, usually with no JS
 * running, so it reads the store from GeofenceStore and the live count straight
 * from Firestore.
 */
object ProximityNotifier {
  private const val TAG = "AllimGeofence"

  /** Same as iOS: one notification per store per hour. */
  private const val COOLDOWN_MILLIS = 60L * 60L * 1000L

  /**
   * A geofence wake is short and the network may be cold. Past this the cached
   * count is used rather than dropping the notification — the iOS
   * liveCountTimeout.
   */
  private const val LIVE_COUNT_TIMEOUT_MILLIS = 4000L

  /** Created by App.tsx with these settings; re-created here if JS never ran. */
  private const val CHANNEL_ID = "allim-reminders"
  private const val CHANNEL_NAME = "Shopping Reminders"

  private val inFlight = HashSet<String>()

  /** Blocking: call from a background thread. */
  fun handleArrival(context: Context, storeKey: String) {
    val store = GeofenceStore.stores(context)[storeKey]
    if (store == null) {
      Log.d(TAG, "Entered a fence for '$storeKey', which is no longer monitored")
      return
    }

    val sinceLast = System.currentTimeMillis() - GeofenceStore.lastNotified(context, storeKey)
    if (sinceLast in 0 until COOLDOWN_MILLIS) {
      Log.d(TAG, "In cooldown for '${store.name}' (notified ${sinceLast / 60000} min ago)")
      return
    }
    if (store.reminderStoreIds.isEmpty()) return

    // Overlapping fences for the same store (two branches close together)
    // mustn't double up. The cooldown is only stamped once something is sent,
    // so a failed check never silences the store for an hour.
    synchronized(inFlight) {
      if (!inFlight.add(storeKey)) return
    }
    try {
      val count = liveReminderCount(store) ?: return
      if (count <= 0) {
        Log.d(TAG, "No reminders waiting at '${store.name}' — skipping")
        return
      }
      if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
        Log.d(TAG, "Notifications are off — not notifying for '${store.name}'")
        return
      }
      GeofenceStore.markNotified(context, storeKey, System.currentTimeMillis())
      post(context, store, count)
    } finally {
      synchronized(inFlight) { inFlight.remove(storeKey) }
    }
  }

  /**
   * Items still to get across every list behind the store, read live: the
   * cached count can be hours old, and a friend may have added to a shared list
   * since. Null means "don't notify" (nobody is signed in); a fetch that fails
   * or runs out of time falls back to the cached count.
   */
  private fun liveReminderCount(store: MonitoredStore): Int? {
    val deadline = System.currentTimeMillis() + LIVE_COUNT_TIMEOUT_MILLIS
    return try {
      val app = FirebaseApp.getInstance()
      val user = FirebaseAuth.getInstance(app).currentUser ?: return null
      val projectId = app.options.projectId ?: return store.cachedCount
      val token = Tasks.await(user.getIdToken(false), remaining(deadline), TimeUnit.MILLISECONDS).token
        ?: return store.cachedCount
      store.reminderStoreIds.distinct().sumOf { id ->
        activeReminderCount(projectId, token, id, deadline)
      }
    } catch (e: Exception) {
      Log.w(TAG, "Live count failed for '${store.name}', using cached (${store.cachedCount})", e)
      store.cachedCount
    }
  }

  /**
   * The Android store badge's count (storeService.activeReminderCount): an
   * unchecked item is still to get, and so is one flagged out of stock.
   *
   * Uses the Firestore REST API with the signed-in user's token rather than the
   * Firestore SDK, so this never starts the SDK instance that
   * @react-native-firebase configures (and clears on sign-out) from JS. The
   * same security rules apply either way.
   */
  private fun activeReminderCount(projectId: String, token: String, userStoreId: String, deadline: Long): Int {
    val query = JSONObject().put(
      "structuredQuery",
      JSONObject()
        .put("from", JSONArray().put(JSONObject().put("collectionId", "reminders")))
        .put(
          "where",
          JSONObject().put(
            "fieldFilter",
            JSONObject()
              .put("field", JSONObject().put("fieldPath", "userStoreId"))
              .put("op", "EQUAL")
              .put("value", JSONObject().put("stringValue", userStoreId)),
          ),
        )
        .put(
          "select",
          JSONObject().put(
            "fields",
            JSONArray()
              .put(JSONObject().put("fieldPath", "isDone"))
              .put(JSONObject().put("fieldPath", "isOutOfStock")),
          ),
        ),
    )

    val url = URL("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery")
    val connection = url.openConnection() as HttpURLConnection
    try {
      val timeout = remaining(deadline).toInt()
      connection.connectTimeout = timeout
      connection.readTimeout = timeout
      connection.requestMethod = "POST"
      connection.doOutput = true
      connection.setRequestProperty("Authorization", "Bearer $token")
      connection.setRequestProperty("Content-Type", "application/json")
      connection.outputStream.use { it.write(query.toString().toByteArray()) }

      val code = connection.responseCode
      if (code !in 200..299) throw IllegalStateException("runQuery returned HTTP $code")
      val body = connection.inputStream.bufferedReader().use { it.readText() }

      // One entry per document, plus entries that carry only a readTime.
      val results = JSONArray(body)
      var count = 0
      for (i in 0 until results.length()) {
        val document = results.optJSONObject(i)?.optJSONObject("document") ?: continue
        val fields = document.optJSONObject("fields") ?: JSONObject()
        val isDone = fields.optJSONObject("isDone")?.optBoolean("booleanValue", false) ?: false
        val isOutOfStock = fields.optJSONObject("isOutOfStock")?.optBoolean("booleanValue", false) ?: false
        if (isOutOfStock || !isDone) count++
      }
      return count
    } finally {
      connection.disconnect()
    }
  }

  private fun remaining(deadline: Long): Long {
    val left = deadline - System.currentTimeMillis()
    if (left <= 0) throw IllegalStateException("Live count timed out")
    return left
  }

  private fun post(context: Context, store: MonitoredStore, count: Int) {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.getNotificationChannel(CHANNEL_ID) == null) {
      manager.createNotificationChannel(
        NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH),
      )
    }

    // The copy is the iOS notification's.
    val place = store.name.trim().ifEmpty { "this store" }
    val title = "📍 You're near $place"
    val body = if (count == 1) {
      "You have 1 reminder waiting for you at $place."
    } else {
      "You have $count reminders waiting for you at $place."
    }

    // Generated from expo.notification.icon in app.config.js.
    val iconRes = context.resources
      .getIdentifier("notification_icon", "drawable", context.packageName)
      .takeIf { it != 0 } ?: context.applicationInfo.icon

    val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
      ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    val contentIntent = launch?.let {
      PendingIntent.getActivity(
        context,
        store.key.hashCode(),
        it,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
      .setSmallIcon(iconRes)
      .setColor(0xFF0B7285.toInt())
      .setContentTitle(title)
      .setContentText(body)
      .setStyle(NotificationCompat.BigTextStyle().bigText(body))
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .setAutoCancel(true)
      .apply { contentIntent?.let { setContentIntent(it) } }
      .build()

    try {
      // One per store, so a later arrival replaces rather than stacks.
      NotificationManagerCompat.from(context).notify("store_proximity", store.key.hashCode(), notification)
      Log.d(TAG, "Notified for '${store.name}' ($count reminders)")
    } catch (e: SecurityException) {
      Log.w(TAG, "POST_NOTIFICATIONS was revoked", e)
    }
  }
}
