package com.langhuan.reader.ui.welcome

import android.content.Intent
import android.os.Bundle
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import com.langhuan.reader.R
import com.langhuan.reader.base.BaseComposeActivity
import com.langhuan.reader.lib.theme.backgroundColor
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.main.MainActivity
import com.langhuan.reader.utils.edgeToEdge
import com.langhuan.reader.utils.setStatusBarColorAuto
import com.langhuan.reader.utils.startActivity
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 启动闪屏：固定品牌页，不再读取自定义欢迎图、显示开关与停留时长。
 */
class WelcomeActivity : BaseComposeActivity() {

    @Composable
    override fun Content() {
        val colors = AppTheme.colors
        Box(
            Modifier
                .fillMaxSize()
                .background(colors.background)
        ) {
            Column(
                Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .width(4.dp)
                            .height(150.dp)
                            .background(colors.accent)
                    )
                    Text(
                        text = "琅\n嬛\n阁",
                        color = colors.accent,
                        fontSize = 42.sp,
                        lineHeight = 46.sp,
                        fontFamily = FontFamily.Serif,
                        modifier = Modifier.padding(start = 14.dp),
                    )
                }
                Spacer(Modifier.height(28.dp))
                Icon(
                    painter = painterResource(R.drawable.icon_read_book),
                    contentDescription = "琅嬛阁",
                    tint = colors.companion,
                    modifier = Modifier.size(64.dp),
                )
            }
        }
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        // 避免从桌面启动程序后，会重新实例化入口类的activity
        if (intent.flags and Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT != 0) {
            finish()
        } else {
            lifecycleScope.launch {
                delay(SPLASH_DURATION_MS)
                startMainActivity()
            }
        }
    }

    override fun setupSystemBar() {
        edgeToEdge()
        setStatusBarColorAuto(backgroundColor, fullScreen)
        upNavigationBarColor()
    }

    private fun startMainActivity() {
        startActivity<MainActivity>()
        finish()
    }

    private companion object {
        const val SPLASH_DURATION_MS = 600L
    }
}
