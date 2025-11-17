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
   - 支持在应用内走完整登录流程：进入 “设置 → Pixiv 凭证 → 登录获取”，浏览器控件会跳转至官方登录页并在授权后自动写入 refresh token；
   - 仍可通过 “手动录入” 粘贴既有 refresh token；
   - 登录过程中会自动查询最新 Pixiv Android 版本并更新所有请求头；
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

## 协议

faio 以 [GNU GPL 3.0](LICENSE) 授权发布，任何衍生作品必须在同协议下进行分享，并在分发时附带本协议文本。

## 致谢

- [Pixez](https://github.com/Notsfsssf/pixez-flutter)：faio 的 Pixiv 体验灵感与部分实现思路参考自该同为 GPL 3.0 的项目，感谢其开源贡献。
- [FurryNovel](https://furrynovel.ink)：提供稳定的 Pixiv 小说代理服务，便于在国内环境下访问相关内容。
- [PixivSource](https://github.com/DowneyRem/PixivSource)：整理了 Pixiv API 以及 FurryNovel API 参考，降低了接入成本。
