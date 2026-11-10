# 琅嬛阁 Web 端

本程序为琅嬛阁的配套 Web 端，由手机端开启 Web 服务后访问；手机和电脑需在同一局域网。

~~在线地址 http://alanskycn.gitee.io/vip/reader/~~

## 具体实现

使用 Vue3 开发

## 功能特性

- 本地存储阅读记录与设置
- 阅读主题切换
- 夜间模式
- 字号调节
- 字体调节
- 阅读宽度调节

## 使用方法

```shell
pnpm install
#安装项目
pnpm dev
#开发模式
pnpm build
#打包
pnpm lint:fix
#格式化代码
```

- 调试的时候可以修改.env.development里面的地址连接手机端调试
