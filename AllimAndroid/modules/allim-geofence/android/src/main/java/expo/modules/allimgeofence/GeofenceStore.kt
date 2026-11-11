package expo.modules.allimgeofence

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** One saved store name, with every list behind it (an owned one plus any shared in). */
data class MonitoredStore(
  val key: String,
  val name: String,
  val reminderStoreIds: List<String>,
  val cachedCount: Int,
)

/** One physical branch of a monitored store. */
data class GeofenceCandidate(
  val key: String,
  val latitude: Double,
  val longitude: Double,
)

/**
 * What the geofences are built from, kept on disk: the receivers run in a
 * process JS may never have started in (a geofence wake, a reboot), so
 * everything they need has to be readable without it.
 */
object GeofenceStore {
  private const val PREFS = "allim_geofence"
  private const val KEY_STORES = "stores"
  private const val KEY_CANDIDATES = "candidates"
  private const val KEY_FENCES = "fences"
  private const val KEY_REF_LAT = "refLat"
  private const val KEY_REF_LNG = "refLng"
  private const val COOLDOWN_PREFIX = "cooldown_"

  private fun prefs(context: Context): SharedPreferences =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

  /** Saves a pool handed over by JS. Returns false if the JSON doesn't parse. */
  fun savePool(context: Context, poolJson: String): Boolean {
    val pool = try {
      JSONObject(poolJson)
    } catch (_: Exception) {
      return false
    }
    val editor = prefs(context).edit()
      .putString(KEY_STORES, pool.optJSONArray("stores")?.toString() ?: "[]")
      .putString(KEY_CANDIDATES, pool.optJSONArray("candidates")?.toString() ?: "[]")
    pool.optJSONObject("reference")?.let { saveReference(editor, it.getDouble("latitude"), it.getDouble("longitude")) }
    editor.apply()
    return true
  }

  fun saveReference(context: Context, latitude: Double, longitude: Double) {
    val editor = prefs(context).edit()
    saveReference(editor, latitude, longitude)
    editor.apply()
  }

  private fun saveReference(editor: SharedPreferences.Editor, latitude: Double, longitude: Double) {
    editor
      .putLong(KEY_REF_LAT, java.lang.Double.doubleToRawLongBits(latitude))
      .putLong(KEY_REF_LNG, java.lang.Double.doubleToRawLongBits(longitude))
  }

  /** Where the fences were last ranked from, or null before the first pool. */
  fun reference(context: Context): Pair<Double, Double>? {
    val p = prefs(context)
    if (!p.contains(KEY_REF_LAT) || !p.contains(KEY_REF_LNG)) return null
    return Pair(
      java.lang.Double.longBitsToDouble(p.getLong(KEY_REF_LAT, 0)),
      java.lang.Double.longBitsToDouble(p.getLong(KEY_REF_LNG, 0)),
    )
  }

  fun stores(context: Context): Map<String, MonitoredStore> {
    val array = parseArray(prefs(context).getString(KEY_STORES, null))
    val result = HashMap<String, MonitoredStore>()
    for (i in 0 until array.length()) {
      val o = array.optJSONObject(i) ?: continue
      val key = o.optString("key").takeIf { it.isNotEmpty() } ?: continue
      val ids = o.optJSONArray("reminderStoreIds") ?: JSONArray()
      result[key] = MonitoredStore(
        key = key,
        name = o.optString("name", ""),
        reminderStoreIds = (0 until ids.length()).mapNotNull { ids.optString(it).takeIf { s -> s.isNotEmpty() } },
        cachedCount = o.optInt("cachedCount", 0),
      )
    }
    return result
  }

  fun candidates(context: Context): List<GeofenceCandidate> {
    val array = parseArray(prefs(context).getString(KEY_CANDIDATES, null))
    return (0 until array.length()).mapNotNull { i ->
      val o = array.optJSONObject(i) ?: return@mapNotNull null
      val key = o.optString("key").takeIf { it.isNotEmpty() } ?: return@mapNotNull null
      if (!o.has("latitude") || !o.has("longitude")) return@mapNotNull null
      GeofenceCandidate(key, o.getDouble("latitude"), o.getDouble("longitude"))
    }
  }

  /** Geofence request id → store key, for the fences currently registered. */
  fun saveFenceMap(context: Context, fences: Map<String, String>) {
    prefs(context).edit().putString(KEY_FENCES, JSONObject(fences).toString()).apply()
  }

  fun storeKeyForFence(context: Context, fenceId: String): String? {
    val raw = prefs(context).getString(KEY_FENCES, null) ?: return null
    return try {
      JSONObject(raw).optString(fenceId).takeIf { it.isNotEmpty() }
    } catch (_: Exception) {
      null
    }
  }

  fun lastNotified(context: Context, storeKey: String): Long =
    prefs(context).getLong(COOLDOWN_PREFIX + storeKey, 0)

  fun markNotified(context: Context, storeKey: String, atMillis: Long) {
    prefs(context).edit().putLong(COOLDOWN_PREFIX + storeKey, atMillis).apply()
  }

  /** Forget everything — the signed-out account's stores must not keep firing. */
  fun clear(context: Context) {
    prefs(context).edit().clear().apply()
  }

  private fun parseArray(raw: String?): JSONArray =
    try {
      if (raw == null) JSONArray() else JSONArray(raw)
    } catch (_: Exception) {
      JSONArray()
    }
}
