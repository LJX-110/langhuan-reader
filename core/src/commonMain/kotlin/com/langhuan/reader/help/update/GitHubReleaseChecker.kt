package com.langhuan.reader.help.update

import com.langhuan.reader.exception.NoStackTraceException
import com.langhuan.reader.help.http.OkHttpClientProviders
import com.langhuan.reader.help.http.newCallResponse
import com.langhuan.reader.help.http.text
import com.langhuan.reader.utils.KS_JSON
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.decodeFromString
import okio.IOException

/**
 * 查项目自己的 GitHub Release (当前四端共用的检测实现)。
 *
 * 流程: 按渠道取 release → [AppVersions] 比版本号 → 按平台后缀 + 架构挑资产。
 * 挑不到本平台资产时仍返回新版本, 只是 [UpdateCheckInfo.downloadUrl] 为空,
 * 弹窗里只剩“浏览器打开”按钮 (指向 release 页)。
 *
 * ### 失败兜底
 * 1. 单次请求 20 秒超时, 避免 API 不可达时一直转圈;
 * 2. 网络异常重试一次; HTTP 状态错误不重试, 直接把状态码带给用户;
 * 3. beta 渠道查 `tags/beta`, 该 tag 不存在 (404) 时回退到 `releases/latest`,
 *    按正式渠道挑资产 —— 之前 beta 包在只有正式 Release 的仓库上必然报错;
 * 4. 失败信息整理成可读文案 (超时/断网/状态码), 不再只抛裸异常。
 *
 * @param repo GitHub `owner/repo`, 便于 fork 或自建镜像替换
 */
class GitHubReleaseChecker(
    private val repo: String = DEFAULT_REPO,
) : UpdateChecker {

    override suspend fun check(request: UpdateCheckRequest): UpdateCheckResult = runCatching {
        val checkVariant = request.checkVariant
        val fetched = fetchRelease(checkVariant)
        val release = fetched.release
        val latestVersion = release.releaseVersion
        if (latestVersion.isBlank()) throw NoStackTraceException("发布信息缺少版本号")
        if (!AppVersions.isNewer(latestVersion, request.currentVersionName)) {
            return@runCatching UpdateCheckResult.UpToDate
        }
        val asset = release.gitReleaseToAppReleaseInfo(request.platform)
            .filter { it.appVariant == fetched.variant }
            .minByOrNull { assetRank(it.name, request.platform, request.supportedAbis) }
        UpdateCheckResult.NewVersion(
            UpdateCheckInfo(
                versionName = latestVersion,
                releaseNote = release.body,
                downloadUrl = asset?.downloadUrl.orEmpty(),
                fileName = asset?.name.orEmpty(),
                landingUrl = release.htmlUrl ?: "https://github.com/$repo/releases",
            )
        )
    }.getOrElse { error ->
        // 调用方主动取消不算检测失败; 超时是 CancellationException 的子类, 要单独留下
        if (error is CancellationException && error !is TimeoutCancellationException) throw error
        UpdateCheckResult.Failed(toReadableError(error))
    }

    /**
     * beta 渠道优先查滚动 tag `beta`; tag 不存在时回退正式版,
     * 并把资产匹配口径一起切回 [AppVariant.OFFICIAL], 否则正式包会被渠道过滤掉。
     */
    private suspend fun fetchRelease(checkVariant: AppVariant): FetchedRelease {
        if (!checkVariant.isBeta()) {
            return FetchedRelease(fetchReleaseByUrl(LATEST_URL(repo)), AppVariant.OFFICIAL)
        }
        val beta = runCatching { fetchReleaseByUrl(BETA_URL(repo)) }
        beta.getOrNull()?.let { return FetchedRelease(it, checkVariant) }
        val error = beta.exceptionOrNull()
        if (error !is ReleaseHttpException || error.statusCode != 404) {
            throw error ?: NoStackTraceException("获取新版本出错")
        }
        return FetchedRelease(fetchReleaseByUrl(LATEST_URL(repo)), AppVariant.OFFICIAL)
    }

    /** 单次 Release 请求: 20 秒超时 + 网络异常重试一次 (HTTP 状态错误不重试)。 */
    private suspend fun fetchReleaseByUrl(url: String): GithubRelease {
        var lastError: Throwable? = null
        repeat(REQUEST_ATTEMPTS) { attempt ->
            try {
                return fetchReleaseOnce(url)
            } catch (e: ReleaseHttpException) {
                throw e
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                lastError = e
                if (attempt == REQUEST_ATTEMPTS - 1) throw e
            }
        }
        throw lastError ?: NoStackTraceException("获取新版本出错")
    }

    private suspend fun fetchReleaseOnce(url: String): GithubRelease = withTimeout(REQUEST_TIMEOUT_MS) {
        val res = OkHttpClientProviders.get().okHttpClient.newCallResponse {
            url(url)
            // GitHub API 对缺少 UA 的匿名请求可能直接 403; Accept 固定 v3 JSON
            header("User-Agent", USER_AGENT)
            header("Accept", "application/vnd.github+json")
        }
        // KmpResponse 实现 Closeable, 必须关闭 (原版 AppUpdate.kt 用 `.use {}`); commonMain 无
        // Closeable.use 扩展, 用 try/finally close() 等价实现, 非 2xx 抛异常分支也确保关闭
        try {
            if (!res.isSuccessful) {
                throw ReleaseHttpException(res.code, "获取新版本出错(${res.code})")
            }
            val body = res.body.text()
            if (body.isBlank()) throw NoStackTraceException("获取新版本出错")
            return@withTimeout KS_JSON.decodeFromString<GithubRelease>(body)
        } finally {
            res.close()
        }
    }

    /** 把超时/断网/HTTP 状态整理成用户能据此行动的一句话。 */
    private fun toReadableError(error: Throwable): Throwable = when (error) {
        is ReleaseHttpException -> {
            val detail = if (error.statusCode == 404) {
                "更新地址不存在（404），可能尚未发布正式版本"
            } else {
                "更新服务返回 ${error.statusCode}"
            }
            NoStackTraceException("$detail，请稍后再试")
        }

        is TimeoutCancellationException ->
            NoStackTraceException("检查更新超时，请检查网络或代理后重试")

        is IOException ->
            NoStackTraceException("网络不可用，无法连接更新服务，请检查网络或代理后重试")

        else -> error
    }

    private data class FetchedRelease(
        val release: GithubRelease,
        /** 实际用于筛选安装包的渠道; beta 回退时与请求渠道不同 */
        val variant: AppVariant,
    )

    private class ReleaseHttpException(
        val statusCode: Int,
        message: String,
    ) : NoStackTraceException(message)

    companion object {
        const val DEFAULT_REPO = "LJX-110/langhuan-reader"

        private const val REQUEST_TIMEOUT_MS = 20_000L
        private const val REQUEST_ATTEMPTS = 2
        private const val USER_AGENT = "LanghuanReader-UpdateChecker"

        private fun LATEST_URL(repo: String) = "https://api.github.com/repos/$repo/releases/latest"

        private fun BETA_URL(repo: String) = "https://api.github.com/repos/$repo/releases/tags/beta"

        /**
         * 资产排序权重: 先按平台后缀优先级 (msi 优于 zip), 再按架构匹配度
         * (本机架构 0 < 通用包 1 < 其它架构 2)。与旧 Android abi 匹配语义一致。
         */
        fun assetRank(
            assetName: String,
            platform: UpdatePlatform,
            supportedAbis: List<String>
        ): Int {
            val lower = assetName.lowercase()
            val suffixIdx = platform.assetSuffixes.indexOfFirst { lower.endsWith(it) }
                .let { if (it < 0) platform.assetSuffixes.size else it }
            val archRank = when {
                AbiTokens.normalize(supportedAbis).any { lower.contains(it) } -> 0
                AbiTokens.universalTokens.any { lower.contains(it) } -> 1
                else -> 2
            }
            return suffixIdx * 10 + archRank
        }
    }
}
