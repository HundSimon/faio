# faio

Furry All In One 是一个聚合常见兽圈站点的 Flutter 客户端。目前已经接入 e621 以及 Pixiv，提供插画、漫画、小说等内容的统一浏览体验。

## 功能概览

- ✅ e621 账号登录与 feed 浏览
- ✅ Pixiv 插画 / 漫画 / 小说信息流（支持分页、下拉刷新）
- ✅ 插画详情页、全屏画廊（支持原图切换、左右滑动）
- ✅ Settings 页面内配置 e621 / Pixiv 凭证
- ⚠️ AIO 聚合页、漫画/小说详情页仍在规划中

## 开发环境

- Flutter 3.22+
- Dart 3.9+

在受限环境下运行 `flutter analyze` / `flutter test` 可能需要手动授予 `/opt/flutter/bin/cache` 写权限。

## 本地配置

1. **e621 API**
   - 在 e621 个人设置生成 [API Key](https://e621.net/help/show/api)；
   - 运行应用后，前往 “设置 → e621 凭证” 填写用户名与 API Key。

2. **Pixiv OAuth**
   - 通过已知的 Pixiv OAuth 流程获取 `refresh_token`（常见做法：抓包移动端登录）；
   - 打开 “设置 → Pixiv 凭证”，粘贴 refresh token；
   - 应用会调用官方接口刷新 access token，并持久化在安全存储中；
   - 未配置 pixiv 凭证时，信息流会退回本地示例数据。

### Pixiv 图片请求

Pixiv 的图片 CDN 需要 `Referer: https://app-api.pixiv.net/` 头；客户端已在加载时自动添加。若计划迁移到其它图片加载库，请确保保留该请求头。

## 目录结构

- `lib/data/e621`：e621 网络层、凭证管理
- `lib/data/pixiv`：Pixiv OAuth、网络层、mock/fallback 服务
- `lib/features/feed`：信息流 UI、分页控制器、详情/画廊页面
- `lib/features/settings`：凭证配置入口

## 后续规划

- 完成 AIO 聚合页与漫画/小说详情体验
- 为 Pixiv API 调用增加容错与本地缓存
- 针对关键数据层编写单元测试与 Widget 测试
