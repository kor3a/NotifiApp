package expo.modules.allimgeofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Puts the geofences back after a reboot or an app update, both of which drop them. */
class GeofenceRestoreReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val pending = goAsync()
    GeofenceRegistrar.restore(context.applicationContext)
      .addOnCompleteListener { task ->
        val status = if (task.isSuccessful) task.result else GeofenceRegistrar.STATUS_ERROR
        Log.d("AllimGeofence", "Restored geofences after ${intent.action}: $status")
        pending.finish()
      }
  }
}
