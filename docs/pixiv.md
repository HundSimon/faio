## Pixiv App API 文档

### 基础信息

- **API 基地址 (Host)**: `https://app-api.pixiv.net`
- **认证方式**: 所有需要认证的请求 (`req_auth=True`) 都必须在请求头中包含 `Authorization` 字段。
  - **Header**: `Authorization: Bearer <YOUR_ACCESS_TOKEN>`
- **通用请求头 (Common Headers)**: 为了模拟 App 行为，建议包含以下请求头：
  - `App-OS`: `ios`
  - `App-OS-Version`: `14.6`
  - `User-Agent`: `PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)`

### 参数类型定义

代码中定义了一些通用的参数类型，其可选值如下：

- `_FILTER`: `"for_ios"`, `""`
- `_TYPE`: `"illust"`, `"manga"`, `""` (插画/漫画)
- `_RESTRICT`: `"public"`, `"private"`, `""` (公开/私密)
- `_CONTENT_TYPE`: `"illust"`, `"manga"`, `""` (内容类型)
- `_MODE`: 排行榜模式
  - `"day"`, `"week"`, `"month"`
  - `"day_male"`, `"day_female"`
  - `"week_original"`, `"week_rookie"`
  - `"day_manga"`
  - R18 相关: `"day_r18"`, `"day_male_r18"`, `"day_female_r18"`, `"week_r18"`, `"week_r18g"`
- `_SEARCH_TARGET`: 搜索目标
  - `"partial_match_for_tags"` (标签部分匹配)
  - `"exact_match_for_tags"` (标签完全匹配)
  - `"title_and_caption"` (标题和描述)
  - `"keyword"` (关键词, 仅用于小说搜索)
- `_SORT`: 排序方式
  - `"date_desc"` (日期降序)
  - `"date_asc"` (日期升序)
  - `"popular_desc"` (热门度降序, 会员功能)
- `_DURATION`: 时间范围
  - `"within_last_day"`
  - `"within_last_week"`
  - `"within_last_month"`

---

### 用户 (User) 相关 API

#### 1. 获取用户详情
- **功能**: 获取指定用户的详细信息。
- **方法**: `GET`
- **路径**: `/v1/user/detail`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
- **需要认证**: 是

#### 2. 获取用户作品列表
- **功能**: 获取指定用户的插画或漫画作品列表。
- **方法**: `GET`
- **路径**: `/v1/user/illusts`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `type` (_TYPE, 可选): 作品类型，`"illust"` 或 `"manga"`。默认为 `"illust"`。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 3. 获取用户收藏的插画/漫画列表
- **功能**: 获取用户收藏的作品列表。
- **方法**: `GET`
- **路径**: `/v1/user/bookmarks/illust`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `restrict` (_RESTRICT, 可选): 收藏的可见性，`"public"` 或 `"private"`。默认为 `"public"`。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `max_bookmark_id` (int, 可选): 用于分页，获取此 ID 之前的收藏。
  - `tag` (str, 可选): 根据收藏标签筛选。
- **需要认证**: 是

#### 4. 获取用户收藏的小说列表
- **功能**: 获取用户收藏的小说列表。
- **方法**: `GET`
- **路径**: `/v1/user/bookmarks/novel`
- **参数**: 与 `user_bookmarks_illust` 类似。
- **需要认证**: 是

#### 5. 获取用户的收藏标签列表
- **功能**: 获取用户为插画收藏设置的所有标签。
- **方法**: `GET`
- **路径**: `/v1/user/bookmark-tags/illust`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `restrict` (_RESTRICT, 可选): 默认为 `"public"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 6. 获取用户关注列表
- **功能**: 获取用户正在关注的用户列表。
- **方法**: `GET`
- **路径**: `/v1/user/following`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `restrict` (_RESTRICT, 可选): 默认为 `"public"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 7. 获取用户粉丝列表
- **功能**: 获取关注指定用户的粉丝列表。
- **方法**: `GET`
- **路径**: `/v1/user/follower`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 8. 关注用户
- **功能**: 添加对一个用户的关注。
- **方法**: `POST`
- **路径**: `/v1/user/follow/add`
- **参数 (Body)**:
  - `user_id` (int, 必填): 要关注的用户 ID。
  - `restrict` (_RESTRICT, 可选): 关注的可见性，默认为 `"public"`。
- **需要认证**: 是

#### 9. 取消关注用户
- **功能**: 取消对一个用户的关注。
- **方法**: `POST`
- **路径**: `/v1/user/follow/delete`
- **参数 (Body)**:
  - `user_id` (int, 必填): 要取消关注的用户 ID。
- **需要认证**: 是

#### 10. 获取用户小说列表
- **功能**: 获取指定用户发布的小说列表。
- **方法**: `GET`
- **路径**: `/v1/user/novels`
- **参数**:
  - `user_id` (int, 必填): 用户 ID。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

---

### 插画/漫画 (Illust) 相关 API

#### 1. 获取作品详情
- **功能**: 获取单个插画/漫画作品的详细信息。
- **方法**: `GET`
- **路径**: `/v1/illust/detail`
- **参数**:
  - `illust_id` (int, 必填): 作品 ID。
- **需要认证**: 是

#### 2. 获取作品评论
- **功能**: 获取作品的评论列表。
- **方法**: `GET`
- **路径**: `/v1/illust/comments`
- **参数**:
  - `illust_id` (int, 必填): 作品 ID。
  - `offset` (int, 可选): 分页偏移量。
  - `include_total_comments` (bool, 可选): 是否返回评论总数，默认为 `false`。
- **需要认证**: 是

#### 3. 获取相关作品列表 (推荐)
- **功能**: 根据一个作品，获取与之相关的推荐作品列表。
- **方法**: `GET`
- **路径**: `/v2/illust/related`
- **参数**:
  - `illust_id` (int, 必填): 作品 ID。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `seed_illust_ids[]` (list[int], 可选): 推荐种子作品 ID 列表。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 4. 获取首页推荐作品
- **功能**: 获取首页的个性化推荐作品（登录后）。如果未登录，则获取通用的推荐作品。
- **方法**: `GET`
- **路径**:
  - 登录后: `/v1/illust/recommended`
  - 未登录: `/v1/illust/recommended-nologin`
- **参数**:
  - `content_type` (_CONTENT_TYPE, 可选): 内容类型，`"illust"` 或 `"manga"`。默认为 `"illust"`。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `offset` (int, 可选): 分页偏移量。
  - `include_ranking_label` (bool, 可选): 是否包含排行标签，默认为 `true`。
- **需要认证**: 推荐（可选）

#### 5. 获取关注用户的新作
- **功能**: 获取已关注用户发布的最新作品。
- **方法**: `GET`
- **路径**: `/v2/illust/follow`
- **参数**:
  - `restrict` (_RESTRICT, 可选): 默认为 `"public"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 6. 获取最新作品 (大家的新作)
- **功能**: 获取平台上最新发布的作品。
- **方法**: `GET`
- **路径**: `/v1/illust/new`
- **参数**:
  - `content_type` (_CONTENT_TYPE, 可选): 默认为 `"illust"`。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `max_illust_id` (int, 可选): 用于分页，获取此 ID 之前的作品。
- **需要认证**: 是

#### 7. 获取作品排行榜
- **功能**: 获取不同模式下的作品排行榜。
- **方法**: `GET`
- **路径**: `/v1/illust/ranking`
- **参数**:
  - `mode` (_MODE, 可选): 排行榜模式，默认为 `"day"`。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `date` (str, 可选): 日期，格式为 `YYYY-MM-DD`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 8. 添加收藏
- **功能**: 将一个作品添加到收藏。
- **方法**: `POST`
- **路径**: `/v2/illust/bookmark/add`
- **参数 (Body)**:
  - `illust_id` (int, 必填): 作品 ID。
  - `restrict` (_RESTRICT, 可选): 收藏的可见性，默认为 `"public"`。
  - `tags[]` (str, 可选): 添加的标签，多个标签用空格分隔。
- **需要认证**: 是

#### 9. 删除收藏
- **功能**: 从收藏中移除一个作品。
- **方法**: `POST`
- **路径**: `/v1/illust/bookmark/delete`
- **参数 (Body)**:
  - `illust_id` (int, 必填): 作品 ID。
- **需要认证**: 是

#### 10. 获取作品收藏详情
- **功能**: 查看作品的收藏状态和标签。
- **方法**: `GET`
- **路径**: `/v2/illust/bookmark/detail`
- **参数**:
  - `illust_id` (int, 必填): 作品 ID。
- **需要认证**: 是

#### 11. 获取动图 (Ugoira) 元数据
- **功能**: 获取动图作品的帧延迟信息和原始图片压缩包 URL。
- **方法**: `GET`
- **路径**: `/v1/ugoira/metadata`
- **参数**:
  - `illust_id` (int, 必填): 动图作品 ID。
- **需要认证**: 是

---

### 小说 (Novel) 相关 API

#### 1. 获取小说详情
- **功能**: 获取单篇小说的详细信息。
- **方法**: `GET`
- **路径**: `/v2/novel/detail`
- **参数**:
  - `novel_id` (int, 必填): 小说 ID。
- **需要认证**: 是

#### 2. 获取小说正文 (Webview)
- **功能**: 获取小说的正文内容和其他 Web 视图信息。
- **方法**: `GET`
- **路径**: `/webview/v2/novel`
- **参数**:
  - `id` (int, 必填): 小说 ID。
  - `viewer_version` (str, 可选): 默认为 `20221031_ai`。
- **需要认证**: 是

#### 3. 获取小说评论
- **功能**: 获取小说的评论列表。
- **方法**: `GET`
- **路径**: `/v1/novel/comments`
- **参数**:
  - `novel_id` (int, 必填): 小说 ID。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 4. 获取小说系列详情
- **功能**: 获取小说系列的所有章节和信息。
- **方法**: `GET`
- **路径**: `/v2/novel/series`
- **参数**:
  - `series_id` (int, 必填): 系列 ID。
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
- **需要认证**: 是

#### 5. 获取关注用户的新小说
- **功能**: 获取已关注用户发布的最新小说。
- **方法**: `GET`
- **路径**: `/v1/novel/follow`
- **参数**:
  - `restrict` (_RESTRICT, 可选): 默认为 `"public"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 6. 获取推荐小说
- **功能**: 获取首页推荐的小说。
- **方法**: `GET`
- **路径**: `/v1/novel/recommended`
- **参数**:
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

---

### 搜索 (Search) 及其他 API

#### 1. 搜索插画/漫画
- **功能**: 根据关键词搜索插画或漫画。
- **方法**: `GET`
- **路径**: `/v1/search/illust`
- **参数**:
  - `word` (str, 必填): 搜索关键词。
  - `search_target` (_SEARCH_TARGET, 可选): 搜索目标，默认为 `"partial_match_for_tags"`。
  - `sort` (_SORT, 可选): 排序方式，默认为 `"date_desc"`。
  - `duration` (_DURATION, 可选): 时间范围筛选。
  - `start_date` (str, 可选): 开始日期，格式 `YYYY-MM-DD`。
  - `end_date` (str, 可选): 结束日期，格式 `YYYY-MM-DD`。
  - `search_ai_type` (int, 可选): `0` 过滤 AI 作品, `1` 显示 AI 作品。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 2. 搜索小说
- **功能**: 根据关键词搜索小说。
- **方法**: `GET`
- **路径**: `/v1/search/novel`
- **参数**:
  - `word` (str, 必填): 搜索关键词。
  - `search_target` (_SEARCH_TARGET, 可选): 搜索目标，默认为 `"partial_match_for_tags"`。
  - `sort` (_SORT, 可选): 排序方式，默认为 `"date_desc"`。
  - 其他参数与搜索插画类似。
- **需要认证**: 是

#### 3. 搜索用户
- **功能**: 根据关键词搜索用户。
- **方法**: `GET`
- **路径**: `/v1/search/user`
- **参数**:
  - `word` (str, 必填): 搜索关键词。
  - `sort` (_SORT, 可选): 排序方式，默认为 `"date_desc"`。
  - `offset` (int, 可选): 分页偏移量。
- **需要认证**: 是

#### 4. 获取热门标签
- **功能**: 获取当前流行的趋势标签。
- **方法**: `GET`
- **路径**: `/v1/trending-tags/illust`
- **参数**:
  - `filter` (_FILTER, 可选): 默认为 `"for_ios"`。
- **需要认证**: 是

#### 5. 获取特辑详情 (Web API)
- **功能**: 获取 Pixivision 特辑文章的详情。这是一个 Web API，不需要 App 的认证头。
- **方法**: `GET`
- **路径**: `https://www.pixiv.net/ajax/showcase/article`
- **参数**:
  - `article_id` (int, 必填): 特辑 ID。
- **需要认证**: 否