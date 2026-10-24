package de.purrtion.app.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

/**
 * Settings store (the Android counterpart of UserDefaults). Keys are the same as on iOS so backups can move
 * between the platforms. Values read through [state] are Compose state: screens recompose when they change.
 */
class Prefs(context: Context) {
    val sp: SharedPreferences = context.getSharedPreferences("purrtion", Context.MODE_PRIVATE)
    private val states = mutableMapOf<String, MutableState<Any?>>()

    @Suppress("UNCHECKED_CAST")
    private fun <T> state(key: String, read: () -> T): MutableState<T> =
        states.getOrPut(key) { mutableStateOf(read()) as MutableState<Any?> } as MutableState<T>

    // MARK: Typed access (observable)

    fun bool(key: String, default: Boolean = false): Boolean = state(key) { readBool(key, default) }.value
    fun int(key: String, default: Int = 0): Int = state(key) { readInt(key, default) }.value
    fun double(key: String, default: Double = 0.0): Double = state(key) { readDouble(key, default) }.value
    fun string(key: String, default: String = ""): String = state(key) { readString(key) ?: default }.value
    fun optString(key: String): String? = state(key) { readString(key) }.value
    fun has(key: String): Boolean = sp.contains(key)

    fun set(key: String, value: Boolean) { sp.edit().putBoolean(key, value).apply(); state(key) { value }.value = value }
    fun set(key: String, value: Int) { sp.edit().putInt(key, value).apply(); state(key) { value }.value = value }
    fun set(key: String, value: Double) {
        sp.edit().putLong(key, java.lang.Double.doubleToRawLongBits(value)).putBoolean("$key#d", true).apply()
        state(key) { value }.value = value
    }
    fun set(key: String, value: String?) {
        if (value == null) sp.edit().remove(key).apply() else sp.edit().putString(key, value).apply()
        state(key) { value }.value = value
    }
    fun remove(key: String) {
        sp.edit().remove(key).remove("$key#d").apply()
        states.remove(key)
    }

    /** Text settings never crash: a value that was stored as another type is read as its text. */
    private fun readString(key: String): String? = try { sp.getString(key, null) } catch (_: ClassCastException) { sp.all[key]?.toString() }

    private fun readBool(key: String, default: Boolean): Boolean = when (val v = sp.all[key]) {
        is Boolean -> v
        is Long -> if (sp.getBoolean("$key#d", false)) java.lang.Double.longBitsToDouble(v) != 0.0 else v != 0L
        is Int -> v != 0
        is String -> v == "1" || v.equals("true", true)
        else -> default
    }

    private fun readInt(key: String, default: Int): Int = when (val v = sp.all[key]) {
        is Int -> v
        is Long -> if (sp.getBoolean("$key#d", false)) java.lang.Double.longBitsToDouble(v).toInt() else v.toInt()
        is Float -> v.toInt()
        is String -> v.toIntOrNull() ?: default
        else -> default
    }

    private fun readDouble(key: String, default: Double): Double = when (val v = sp.all[key]) {
        is Long -> if (sp.getBoolean("$key#d", false)) java.lang.Double.longBitsToDouble(v) else v.toDouble()
        is Int -> v.toDouble()
        is Float -> v.toDouble()
        is String -> v.toDoubleOrNull() ?: default
        else -> default
    }

    /** All settings as "s:"/"n:" strings – the backup format of the iOS app. */
    fun export(prefixes: List<String>): Map<String, String> {
        val out = mutableMapOf<String, String>()
        for ((k, v) in sp.all) {
            if (k.endsWith("#d") || prefixes.none { k.startsWith(it) }) continue
            when (v) {
                is String -> out[k] = "s:$v"
                is Boolean -> out[k] = "n:${if (v) 1 else 0}"
                is Int -> out[k] = "n:$v"
                is Long -> out[k] = "n:${if (sp.getBoolean("$k#d", false)) java.lang.Double.longBitsToDouble(v) else v}"
                is Float -> out[k] = "n:$v"
            }
        }
        return out
    }

    /** Restores settings from a backup. Numbers are stored as doubles; [bool] and [int] read them back. */
    fun import(settings: Map<String, String>) {
        val e = sp.edit()
        for ((k, v) in settings) {
            when {
                v.startsWith("s:") -> e.putString(k, v.drop(2))
                v.startsWith("n:") -> {
                    val d = v.drop(2).toDoubleOrNull() ?: continue
                    e.putLong(k, java.lang.Double.doubleToRawLongBits(d)).putBoolean("$k#d", true)
                }
            }
        }
        e.apply()
        states.clear()
    }
}

/** Property delegates for settings objects. */
class BoolPref(private val prefs: Prefs, private val key: String, private val default: Boolean) : ReadWriteProperty<Any?, Boolean> {
    override fun getValue(thisRef: Any?, property: KProperty<*>) = prefs.bool(key, default)
    override fun setValue(thisRef: Any?, property: KProperty<*>, value: Boolean) = prefs.set(key, value)
}

class IntPref(private val prefs: Prefs, private val key: String, private val default: Int) : ReadWriteProperty<Any?, Int> {
    override fun getValue(thisRef: Any?, property: KProperty<*>) = prefs.int(key, default)
    override fun setValue(thisRef: Any?, property: KProperty<*>, value: Int) = prefs.set(key, value)
}

class DoublePref(private val prefs: Prefs, private val key: String, private val default: Double) : ReadWriteProperty<Any?, Double> {
    override fun getValue(thisRef: Any?, property: KProperty<*>) = prefs.double(key, default)
    override fun setValue(thisRef: Any?, property: KProperty<*>, value: Double) = prefs.set(key, value)
}

class StringPref(private val prefs: Prefs, private val key: String, private val default: String) : ReadWriteProperty<Any?, String> {
    override fun getValue(thisRef: Any?, property: KProperty<*>) = prefs.string(key, default)
    override fun setValue(thisRef: Any?, property: KProperty<*>, value: String) = prefs.set(key, value)
}
