package io.legado.runner

import io.legado.app.help.config.PreferenceProvider
import io.legado.app.help.config.PreferenceProviders

/** 内存版 PreferenceProvider（runner 无磁盘配置需求）。 */
class RunnerPreferenceProvider : PreferenceProvider {
    private val map = mutableMapOf<String, Any>()
    private val listeners = mutableListOf<(String) -> Unit>()

    override fun getString(key: String, default: String): String =
        map[key] as? String ?: default

    override fun getStringOrNull(key: String): String? = map[key] as? String

    override fun getInt(key: String, default: Int): Int =
        map[key] as? Int ?: default

    override fun getBoolean(key: String, default: Boolean): Boolean =
        map[key] as? Boolean ?: default

    override fun getLong(key: String, default: Long): Long =
        map[key] as? Long ?: default

    override fun getFloat(key: String, default: Float): Float =
        map[key] as? Float ?: default

    override fun putString(key: String, value: String?) {
        if (value == null) map.remove(key) else map[key] = value
        notifyChanged(key)
    }

    override fun putInt(key: String, value: Int) {
        map[key] = value
        notifyChanged(key)
    }

    override fun putBoolean(key: String, value: Boolean) {
        map[key] = value
        notifyChanged(key)
    }

    override fun putLong(key: String, value: Long) {
        map[key] = value
        notifyChanged(key)
    }

    override fun putFloat(key: String, value: Float) {
        map[key] = value
        notifyChanged(key)
    }

    override fun remove(key: String) {
        map.remove(key)
        notifyChanged(key)
    }

    override fun contains(key: String): Boolean = map.containsKey(key)

    override fun getAll(): Map<String, *> = map.toMap()

    override fun addPreferenceChangeListener(
        listener: (key: String) -> Unit,
    ): () -> Unit {
        listeners.add(listener)
        return { listeners.remove(listener) }
    }

    private fun notifyChanged(key: String) {
        listeners.toList().forEach { it(key) }
    }
}

fun registerRunnerPreferences() {
    PreferenceProviders.register(RunnerPreferenceProvider())
}
