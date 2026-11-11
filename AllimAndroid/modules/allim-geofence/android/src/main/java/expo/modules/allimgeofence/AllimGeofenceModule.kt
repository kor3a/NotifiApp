package expo.modules.allimgeofence

import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * JS entry point. JS owns finding the stores and their branches (Firestore
 * listeners, the cached Places lookup); native owns the geofences and
 * everything that has to happen while the app is closed.
 */
class AllimGeofenceModule : Module() {
  private val context
    get() = requireNotNull(appContext.reactContext) { "React context is not available" }

  override fun definition() = ModuleDefinition {
    Name("AllimGeofence")

    /**
     * Replace the monitored stores and their candidate branches, then register
     * fences ranked from `reference`. Resolves to a GeofenceRegistrar STATUS_.
     */
    AsyncFunction("setPool") { poolJson: String, promise: Promise ->
      if (!GeofenceStore.savePool(context, poolJson)) {
        promise.reject(CodedException("ERR_BAD_POOL", "Geofence pool is not valid JSON", null))
        return@AsyncFunction
      }
      GeofenceRegistrar.restore(context).addOnCompleteListener { task ->
        promise.resolve(if (task.isSuccessful) task.result else GeofenceRegistrar.STATUS_ERROR)
      }
    }

    /** Stop monitoring and forget the account's stores (sign-out). */
    AsyncFunction("clear") { promise: Promise ->
      GeofenceRegistrar.clear(context).addOnCompleteListener { promise.resolve(null) }
    }

    /** What would stop geofences working right now, or null if nothing. */
    Function("permissionProblem") {
      GeofenceRegistrar.permissionProblem(context)
    }
  }
}
