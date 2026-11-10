@file:OptIn(kotlin.time.ExperimentalTime::class)

package com.langhuan.reader.data.entities

import androidx.room3.Entity
import androidx.room3.PrimaryKey
import kotlin.time.Clock
import kotlinx.serialization.Serializable

@Serializable
@Entity(tableName = "ruleSubs")
data class RuleSub(
    @PrimaryKey
    val id: Long = Clock.System.now().toEpochMilliseconds(),
    var name: String = "",
    var url: String = "",
    var type: Int = 0,
    var customOrder: Int = 0,
    /** 是否每天自动更新一次 (距上次更新满一天才跑, 见 [com.langhuan.reader.help.storage.RuleSubAutoUpdate])。 */
    var autoUpdate: Boolean = false,
    var update: Long = Clock.System.now().toEpochMilliseconds()
)
