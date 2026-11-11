package expo.modules.allimgeofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Geofence transitions, delivered by Google Play services whether or not the
 * app is running. Entering a store's circle may notify; leaving the refresh
 * circle re-ranks the fences from the new position.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val event = GeofencingEvent.fromIntent(intent) ?: return
    if (event.hasError()) {
      // GEOFENCE_NOT_AVAILABLE: location was turned off and Android dropped
      // every fence. The app re-registers them the next time it opens.
      Log.w(TAG, "Geofence error ${event.errorCode}")
      return
    }
    val fenceIds = event.triggeringGeofences?.map { it.requestId }.orEmpty()
    if (fenceIds.isEmpty()) return

    val app = context.applicationContext
    val transition = event.geofenceTransition
    val location = event.triggeringLocation

    // The live count is a network call; keep the broadcast alive for it.
    val pending = goAsync()
    executor.execute {
      try {
        when (transition) {
          Geofence.GEOFENCE_TRANSITION_ENTER ->
            fenceIds
              .filter { it != GeofenceRegistrar.REFRESH_FENCE_ID }
              .mapNotNull { GeofenceStore.storeKeyForFence(app, it) }
              .distinct()
              .forEach { ProximityNotifier.handleArrival(app, it) }

          Geofence.GEOFENCE_TRANSITION_EXIT ->
            if (GeofenceRegistrar.REFRESH_FENCE_ID in fenceIds && location != null) {
              val status = Tasks.await(
                GeofenceRegistrar.register(app, location.latitude, location.longitude),
                REGISTER_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
              )
              Log.d(TAG, "Re-ranked geofences after moving: $status")
            }
        }
      } catch (e: Exception) {
        Log.w(TAG, "Handling geofence transition failed", e)
      } finally {
        pending.finish()
      }
    }
  }

  companion object {
    private const val TAG = "AllimGeofence"
    private const val REGISTER_TIMEOUT_SECONDS = 8L
    private val executor = Executors.newSingleThreadExecutor()
  }
}
