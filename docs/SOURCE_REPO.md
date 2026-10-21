# 私有书源仓库

## 原则

- 应用不内置、不提供、不推荐任何书源。
- 应用不保存任何默认仓库地址。
- 只有使用者在「我的 → 私有书源仓库」里填写地址并点击同步时，才会发起网络请求。
- 仓库内容由使用者自行维护；应用只负责解析和写入本机数据库。

## 支持的 JSON 形式

推荐使用带元信息的清单：

```json
{
  "name": "我的书源",
  "version": "1",
  "updatedAt": "2026-10-21",
  "sources": []
}
```

`source` 数组里的每一项是 Legado 书源对象，至少包含：

```json
{
  "bookSourceUrl": "https://example.com",
  "bookSourceName": "示例书源",
  "bookSourceType": 0,
  "enabled": true,
  "searchUrl": "",
  "exploreUrl": "",
  "ruleSearch": {},
  "ruleExplore": {},
  "ruleBookInfo": {},
  "ruleToc": {},
  "ruleContent": {}
}
```

也支持：

- 裸数组：`[ { ...书源... }, { ...书源... } ]`
- `{ "data": [ ...书源... ] }`
- 单本书源对象：`{ "bookSourceUrl": "...", "bookSourceName": "..." }`

应用不会在仓库里内置示例书源；上面的对象只描述字段形状。

## 同步行为

1. 校验 URL 必须是 `http` / `https`。
2. 用 Dio 下载 JSON，超时 15s / 60s。
3. `SourceImporter.parseJson` 解析，跳过没有 `bookSourceUrl` 或 `bookSourceName` 的条目。
4. 按 `bookSourceUrl` upsert 到 `sources` 表：已有则更新，没有则插入。
5. 成功后记录仓库名与同步时间；失败只提示，不改动已有书源。
6. 同步不会删除本地已有书源，也不会自动覆盖手动导入的书源。

## 私有仓库怎么托管

- 最简单：一个公开 GitHub 仓库，里面放 `sources.json`，用 raw 地址；仓库不对外宣传即可。
- 需要真正私有：GitHub 私有仓库的 raw 地址需要 token，本应用目前不保存 token。可以：
  - 用带随机路径的自建 HTTPS 端点；或
  - 用 Cloudflare Workers / Vercel 等做一层需要密钥的代理；或
  - 后续给应用增加自定义请求头（需要另行设计密钥存储）。
- 不要把 GitHub token 写进仓库、APK 或截图。

## 代码位置

- 抓取与清单解析：`lib/source/repo/source_repo.dart`
- JSON 解析：`lib/source/import/source_importer.dart`
- 入库：`lib/model/source_model.dart` → `SourceRepository`
- 页面：`lib/view/person/source_repo_page.dart`
- 入口：`我的 → 私有书源仓库`、`书源管理 → 私有仓库`

## 合规边界

- 只导入你有权访问和使用的书源。
- 不把公开书源列表打包进 APK，不在 README 里提供书源下载地址。
- 应用不绕过付费墙、不破解 DRM、不内置盗版内容。
