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
2. 可选填 GitHub 只读 Token：地址支持 `raw.githubusercontent.com`、`github.com/.../blob/...` 或 `api.github.com/.../contents/...`；带 Token 时自动改用 Contents 接口（`Authorization: Bearer`），Token 只存本机、只发给 GitHub 域名，不写日志，非 GitHub 地址填 Token 会直接报错。
3. 用 Dio 下载 JSON，超时 15s / 60s。
4. `SourceImporter.parseJson` 解析；`bookSourceUrl` 与 `bookSourceName` 都为空的条目跳过，缺少 URL 的条目会生成本地 id。
5. 先读取本地已有书源，按 `bookSourceUrl` 判断哪些已存在，并在弹窗中说明「已存在 / 新书源」数量。
6. 默认选择「保留本地」：只插入新书源，已有书源的规则、顺序、启停与健康度都不改动；只有用户明确选择「覆盖本地规则」才更新已有书源。手动导入会跳过规则完全相同的已有书源；仓库覆盖按用户确认更新。
7. 默认保留路径与覆盖路径都在单个数据库事务内完成；任一行写入失败，整批回滚，不会留下半批书源。页面会提示「同步失败，未写入任何书源」并保留原列表。
8. 写入成功后记录仓库名与同步时间并重新加载列表；如果写入已经完成、仅后续刷新失败，会单独提示并再次尝试刷新，不谎称已回滚。
9. 同步不会删除本地已有书源。

手动粘贴 JSON 与 URL 导入使用同一套规则比对和事务写入语义：只有检测到已有书源规则不同时才询问「保留本地 / 覆盖本地规则」，并显示受影响数量。

## 私有仓库怎么托管

- 公开 GitHub 仓库：直接放整包 JSON（如 `packages/all.json`），用 raw 地址，无需 Token。
- 私有 GitHub 仓库：在页面里填 **只读 Token**（fine-grained，仓库范围只选该仓库、Contents 只读）。带 Token 时应用走 Contents API，不依赖 `raw.githubusercontent` 的私有访问。
- 自建 HTTPS 端点或带密钥的代理同样可用，填完整地址即可。
- 不要把 Token 写进仓库、APK 或截图；Token 只保存在本机 SharedPreferences，可随时清空。
- 仓库组织方式（分类目录、订阅包、校验报告、结构校验脚本）可参考自用模板：`sources/<分类>/*.json` + `packages/all.json` + `index.json` + `reports/`。

## 代码位置

- 抓取与清单解析：`lib/features/sources/repo/source_repo.dart`
- JSON 解析：`lib/features/sources/import/source_importer.dart`
- 规则比对与覆盖决策：`lib/features/sources/import/source_import_conflict.dart`
- 入库：`lib/features/sources/source_model.dart` → `SourceRepository`（单事务）
- 页面：`lib/features/sources/source_repo_page.dart`
- 入口：`我的 → 私有书源仓库`、`书源管理 → 私有仓库`

## 合规边界

- 只导入你有权访问和使用的书源。
- 不把公开书源列表打包进 APK，不在 README 里提供书源下载地址。
- 应用不绕过付费墙、不破解 DRM、不内置盗版内容。
