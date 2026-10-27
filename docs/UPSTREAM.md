# 上游底本与许可

## 底本

- 仓库：`https://github.com/leetomlee123/book.git`
- 固定提交：`0b25219cf7ebdbd2b166f9a299c239f21fc721a0`
- 许可：Apache License 2.0

琅嬛阁在该底本上做了大量删改与重写，但以下内容仍然保留：

- 上游许可原文 `third_party/Apache-2.0.txt`
- 第三方组件自己的许可文本，例如 `third_party/flutter_js/LICENSE`
- 字体许可，例如 `assets/fonts/HarmonyOS_Sans_SC_LICENSE.txt`
- 根目录 `NOTICE` 中的上游归属说明

## 本仓库许可

- 根目录 `LICENSE` 是 **GPL-3.0**：本仓库自 2.1.1 起移植了 Wenku8-Local 的 3D 书架
  （GPL-3.0），整体按 GPL-3.0 分发。上游 Apache-2.0 部分与 GPL-3.0 兼容，
  其许可原文与归属说明分别保留在 `third_party/Apache-2.0.txt` 与 `NOTICE`。

## 已移除的上游内容

- Firebase Analytics / Crashlytics 依赖、初始化、google-services 配置
- GitHub Releases OTA 更新服务、更新弹窗、安装权限
- 上游公开书源仓库（yckceo）页面与抓取逻辑
- 上游签名文件 `key.jks`、`key.properties`
- 上游 README 截图、英文 README、维护者文档、CI 配置
- 界面中的上游名称、邮箱、GitHub 地址、反馈入口

## 边界

- 不把上游作者写成这个项目的作者；`NOTICE` 只说明来源与许可。
- Wenku8-Local 的代码可按 GPL-3.0 移植（2026-10-26 用户决定）；移植处必须在 `NOTICE` 署名，且本仓库保持 GPL-3.0。
- 上游历史提交不进入本仓库；本仓库从清理后的初始提交开始。
