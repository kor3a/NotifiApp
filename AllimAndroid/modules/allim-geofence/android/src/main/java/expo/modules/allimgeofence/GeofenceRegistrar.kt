package expo.modules.allimgeofence

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks

/**
 * Turns the saved pool into registered geofences. Port of the iOS
 * LocationMonitoringManager.registerGeofences: stores with reminders waiting
 * win the slots, nearer beats farther.
 *
 * Android allows 100 geofences per app (iOS: 20), so the budget is far less
 * tight, but it still has to be re-ranked as the user moves. iOS does that off
 * significant-change updates; here one large "refresh" fence around the point
 * the ranking was made from fires on exit and re-ranks from wherever the user
 * is then — without JS, since the app may not be running.
 */
object GeofenceRegistrar {
  private const val TAG = "AllimGeofence"
  const val ACTION_GEOFENCE_EVENT = "expo.modules.allimgeofence.GEOFENCE_EVENT"

  /** The iOS proximity threshold. Google recommends no less than 100–150 m. */
  const val STORE_RADIUS_METERS = 150f

  /** Leaving this circle re-ranks the fences from the new position. */
  const val REFRESH_RADIUS_METERS = 3000f
  const val REFRESH_FENCE_ID = "allim_refresh"
  private const val STORE_FENCE_PREFIX = "s"

  /** 100 per app, less the refresh fence and a little headroom. */
  private const val MAX_STORE_FENCES = 95

  const val STATUS_REGISTERED = "registered"
  const val STATUS_NO_STORES = "noStores"
  const val STATUS_NEEDS_FINE_LOCATION = "needsFineLocation"
  const val STATUS_NEEDS_BACKGROUND_LOCATION = "needsBackgroundLocation"
  const val STATUS_ERROR = "error"

  fun pendingIntent(context: Context): PendingIntent {
    val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
      .setAction(ACTION_GEOFENCE_EVENT)
    // Play services fills the transition into the intent, so it must be mutable.
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
      (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
    return PendingIntent.getBroadcast(context, 0, intent, flags)
  }

  /**
   * Geofencing needs precise location, and from Android 10 it only fires while
   * the app is closed with "Allow all the time".
   */
  fun permissionProblem(context: Context): String? {
    fun granted(permission: String) =
      ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    if (!granted(Manifest.permission.ACCESS_FINE_LOCATION)) return STATUS_NEEDS_FINE_LOCATION
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
      !granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    ) {
      return STATUS_NEEDS_BACKGROUND_LOCATION
    }
    return null
  }

  /**
   * Re-rank the saved pool from ([latitude], [longitude]) and swap the
   * registered fences for the result. The task resolves to one of the STATUS_
   * values and never fails.
   */
  @SuppressLint("MissingPermission") // Checked by permissionProblem().
  fun register(context: Context, latitude: Double, longitude: Double): Task<String> {
    val app = context.applicationContext
    GeofenceStore.saveReference(app, latitude, longitude)

    permissionProblem(app)?.let { return Tasks.forResult(it) }

    val stores = GeofenceStore.stores(app)
    val selected = GeofenceStore.candidates(app)
      .filter { stores.containsKey(it.key) }
      .map { it to distance(latitude, longitude, it.latitude, it.longitude) }
      .sortedWith(
        compareByDescending<Pair<GeofenceCandidate, Float>> { (stores[it.first.key]?.cachedCount ?: 0) > 0 }
          .thenBy { it.second },
      )
      .take(MAX_STORE_FENCES)

    val client = LocationServices.getGeofencingClient(app)
    val intent = pendingIntent(app)

    if (selected.isEmpty()) {
      GeofenceStore.saveFenceMap(app, emptyMap())
      return client.removeGeofences(intent).continueWith { STATUS_NO_STORES }
    }

    val fenceMap = HashMap<String, String>()
    val fences = ArrayList<Geofence>(selected.size + 1)
    selected.forEachIndexed { index, (candidate, _) ->
      val id = "$STORE_FENCE_PREFIX$index"
      fenceMap[id] = candidate.key
      fences.add(
        Geofence.Builder()
          .setRequestId(id)
          .setCircularRegion(candidate.latitude, candidate.longitude, STORE_RADIUS_METERS)
          .setExpirationDuration(Geofence.NEVER_EXPIRE)
          .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
          .build(),
      )
    }
    fences.add(
      Geofence.Builder()
        .setRequestId(REFRESH_FENCE_ID)
        .setCircularRegion(latitude, longitude, REFRESH_RADIUS_METERS)
        .setExpirationDuration(Geofence.NEVER_EXPIRE)
        .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
        .build(),
    )

    // No initial trigger, as on iOS: being inside a store's circle at the
    // moment it is registered (say, opening the app in the car park) doesn't
    // count as arriving.
    val request = GeofencingRequest.Builder()
      .setInitialTrigger(0)
      .addGeofences(fences)
      .build()

    GeofenceStore.saveFenceMap(app, fenceMap)

    return client.removeGeofences(intent)
      .continueWithTask { client.addGeofences(request, intent) }
      .continueWith { task ->
        if (task.isSuccessful) {
          Log.d(TAG, "Registered ${selected.size} store geofence(s) + refresh fence")
          STATUS_REGISTERED
        } else {
          Log.w(TAG, "Could not register geofences", task.exception)
          STATUS_ERROR
        }
      }
  }

  /** Re-register from wherever the fences were last ranked. */
  fun restore(context: Context): Task<String> {
    val reference = GeofenceStore.reference(context) ?: return Tasks.forResult(STATUS_NO_STORES)
    return register(context, reference.first, reference.second)
  }

  fun clear(context: Context): Task<Void> {
    val app = context.applicationContext
    GeofenceStore.clear(app)
    return LocationServices.getGeofencingClient(app).removeGeofences(pendingIntent(app))
  }

  private fun distance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Float {
    val out = FloatArray(1)
    Location.distanceBetween(lat1, lng1, lat2, lng2, out)
    return out[0]
  }
}
