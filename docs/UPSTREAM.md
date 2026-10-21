# 上游底本与许可

## 底本

- 仓库：`https://github.com/leetomlee123/book.git`
- 固定提交：`0b25219cf7ebdbd2b166f9a299c239f21fc721a0`
- 许可：Apache License 2.0（见根目录 `LICENSE`）

琅嬛阁在该底本上做了大量删改与重写，但以下内容仍然保留：

- 根目录 `LICENSE`（Apache-2.0 全文）
- 第三方组件自己的许可文本，例如 `third_party/flutter_js/LICENSE`
- 字体许可，例如 `assets/fonts/HarmonyOS_Sans_SC_LICENSE.txt`
- 根目录 `NOTICE` 中的上游归属说明

## 已移除的上游内容

- Firebase Analytics / Crashlytics 依赖、初始化、google-services 配置
- GitHub Releases OTA 更新服务、更新弹窗、安装权限
- 上游公开书源仓库（yckceo）页面与抓取逻辑
- 上游签名文件 `key.jks`、`key.properties`
- 上游 README 截图、英文 README、维护者文档、CI 配置
- 界面中的上游名称、邮箱、GitHub 地址、反馈入口

## 边界

- 不把上游作者写成这个项目的作者；`NOTICE` 只说明来源与许可。
- 不复制 Wenku8 等 GPL 项目的代码；只参考视觉与交互。
- 上游历史提交不进入本仓库；本仓库从清理后的初始提交开始。
