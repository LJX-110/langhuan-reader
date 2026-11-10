package com.langhuan.reader.help

import com.langhuan.reader.data.entities.ReplaceRule
import com.langhuan.reader.exception.NoStackTraceException
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.fromJsonObject
import com.langhuan.reader.utils.parseJsonElement
import com.langhuan.reader.utils.readBool
import com.langhuan.reader.utils.readInt
import com.langhuan.reader.utils.readLong
import com.langhuan.reader.utils.readString
import com.langhuan.reader.utils.systemCurrentTimeMillis
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

object ReplaceAnalyzer {

    fun jsonToReplaceRules(json: String): Result<MutableList<ReplaceRule>> {
        return kotlin.runCatching {
            val replaceRules = mutableListOf<ReplaceRule>()
            val jsonElement = parseJsonElement(json)
            val items: JsonArray = jsonElement.jsonArray
            for (item in items) {
                val jsonItem = item.jsonObject
                jsonToReplaceRule(jsonItem.toString()).getOrThrow().let {
                    if (it.isValid()) {
                        replaceRules.add(it)
                    }
                }
            }
            replaceRules
        }
    }

    fun jsonToReplaceRule(json: String): Result<ReplaceRule> {
        return runCatching {
            val replaceRule: ReplaceRule? =
                GSON.fromJsonObject<ReplaceRule>(json.trim()).getOrNull()
            if (replaceRule == null || replaceRule.pattern.isEmpty()) {
                val jsonItem = parseJsonElement(json.trim())
                val rule = ReplaceRule()
                rule.id = jsonItem.readLong("$.id") ?: systemCurrentTimeMillis()
                rule.pattern = jsonItem.readString("$.regex") ?: ""
                if (rule.pattern.isEmpty()) throw NoStackTraceException("格式不对")
                rule.isRegex = jsonItem.readBool("$.isRegex") ?: false
                rule.replacement = jsonItem.readString("$.replacement") ?: ""
                //兼容旧字段: name/replaceSummary, scope/useTo, isEnabled/enable, order/serialNumber
                rule.name = jsonItem.readString("$.name")
                    ?: jsonItem.readString("$.replaceSummary") ?: ""
                rule.isEnabled = jsonItem.readBool("$.isEnabled")
                    ?: jsonItem.readBool("$.enable") ?: true
                rule.order = jsonItem.readInt("$.order")
                    ?: jsonItem.readInt("$.serialNumber") ?: 0
                rule.scope = jsonItem.readString("$.scope")
                    ?: jsonItem.readString("$.useTo")
                rule.group = jsonItem.readString("$.group") ?: ""
                rule
            } else {
                replaceRule
            }
        }
    }

}
