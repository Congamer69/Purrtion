package de.purrtion.app.domain

import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import de.purrtion.app.App

/** API keys and the anonymous Firebase account – encrypted with the Android Keystore (the Keychain counterpart). */
object Secrets {
    private val sp: SharedPreferences by lazy {
        val key = MasterKey.Builder(App.context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        EncryptedSharedPreferences.create(App.context, "purrtion_secrets", key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
    }

    fun get(key: String): String? = runCatching { sp.getString(key, null) }.getOrNull()

    fun set(key: String, value: String?) {
        if (value.isNullOrEmpty()) sp.edit().remove(key).apply() else sp.edit().putString(key, value).apply()
    }
}
