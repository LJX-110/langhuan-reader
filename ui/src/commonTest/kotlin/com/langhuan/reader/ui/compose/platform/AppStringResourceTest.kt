package com.langhuan.reader.ui.compose.platform

import com.langhuan.reader.help.i18n.AppStringKey
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.allStringResources
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * 每个 [AppStringKey] 都必须有同名 composeResources 条目。
 *
 * `appString` 在查不到 key 时会原样返回 key 名，界面就会出现 `data_loading`
 * 这类英文占位；这条测试把「漏条文案」挡在编译期之后、发版之前。
 */
class AppStringResourceTest {

    @Test
    fun everyAppStringKeyHasResource() {
        val missing = AppStringKey.entries
            .map { it.name }
            .filterNot { it in Res.allStringResources }

        assertTrue(
            missing.isEmpty(),
            "AppStringKey 缺少 composeResources 条目: ${missing.joinToString()}",
        )
    }
}
