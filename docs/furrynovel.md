### 1. 小说 (Novels)

#### 1.1 获取单篇小说详情
获取指定 ID 的单篇小说的详细信息，包括内容、标签、作者等。

- **方法:** `GET`
- **Endpoint:** `/pixiv/novel/{novelId}/cache`
- **路径参数:**
    - `{novelId}` (必填): 小说的 ID。
- **示例:** `https://api.furrynovel.ink/pixiv/novel/12345678/cache`
- **响应示例 (节选，自 `GET https://api.furrynovel.ink/pixiv/novel/26259641/cache`，content 字段出于篇幅只展示前 160 个字符)：**
  ```json
  {
    "id": "26259641",
    "title": "LINPX x口袋英雄 盲盒飞机杯征文企划",
    "userName": "自然可可",
    "userId": "3462850",
    "content": "本次活动是由LINPX和趣奇工作室合作举办，以“牛头人英雄米诺忒斯”为主题的征文活动。  我们诚挚邀请邀请兽人文学及英雄文学爱好者围绕“米诺忒斯”创作原创故事。无论您选择挖掘其作为英雄的心路历程，抑或是探索其逐渐恶堕的相关细节，我们都相信您的文字会丰满该角色形象，赋予其独一无二的生命力。  活动时间： 2025年10月...",
    "tags": [
      "furry",
      "米诺忒斯",
      "征文比赛"
    ],
    "coverUrl": "https://i.pximg.net/c/600x600/novel-cover-master/img/2025/10/22/21/29/39/ci26259641_23bb6bac2c2ac5b454989073a9b43fa7_master1200.jpg",
    "createDate": "2025-10-22T12:29:39+00:00",
    "pixivLikeCount": 0,
    "images": {
      "22538288": {
        "preview": "https://i.pximg.net/c/480x960/novel-cover-master/img/2025/10/22/21/28/35/tei755782424608_71675bd5b29ba4b722b135bb305f6897_master1200.jpg",
        "origin": "https://i.pximg.net/c/1200x1200/novel-cover-master/img/2025/10/22/21/28/35/tei755782424608_71675bd5b29ba4b722b135bb305f6897_master1200.jpg"
      },
      "22538289": {
        "preview": "https://i.pximg.net/c/480x960/novel-cover-master/img/2025/10/22/21/28/35/tei57989659948_ec72528fefa44aa2ccc602c4ea6c744d_master1200.jpg",
        "origin": "https://i.pximg.net/c/1200x1200/novel-cover-master/img/2025/10/22/21/28/35/tei57989659948_ec72528fefa44aa2ccc602c4ea6c744d_master1200.jpg"
      }
    }
  }
  ```

#### 1.2 批量获取小说详情
通过小说 ID 列表，一次性获取多篇小说的基本信息。

- **方法:** `GET`
- **Endpoint:** `/pixiv/novels/cache`
- **查询参数:**
    - `ids[]` (必填): 小说 ID 数组。
- **示例:** `https://api.furrynovel.ink/pixiv/novels/cache?ids[]=12345678&ids[]=87654321`
- **响应:** 返回一个小说对象组成的数组，结构与 `1.1` 类似但可能不包含 `content` 字段。
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/novels/cache?ids[]=26259641&ids[]=26428468`):**
  ```json
  [
    {
      "id": "26259641",
      "title": "LINPX x口袋英雄 盲盒飞机杯征文企划",
      "userName": "自然可可",
      "tags": [
        "furry",
        "米诺忒斯",
        "征文比赛"
      ],
      "length": 492,
      "createDate": "2025-10-22T21:29:39+09:00",
      "pixivLikeCount": 0,
      "seriesId": null
    },
    {
      "id": "26428468",
      "title": "神秘出手赤龙不会遇到第五人格煌黑(事实上里面不包含一点第五人格成分)",
      "userName": "明月伴我行",
      "tags": [
        "R-18",
        "兽人",
        "龙",
        "同性向",
        "纯爱",
        "龙兽人",
        "第五人格含量0"
      ],
      "length": 12347,
      "createDate": "2025-11-11T00:57:29+09:00",
      "pixivLikeCount": 10,
      "seriesId": null
    }
  ]
  ```

#### 1.3 获取最新小说
按分页获取最近更新的小说列表。

- **方法:** `GET`
- **Endpoint:** `/pixiv/novels/recent/cache`
- **查询参数:**
    - `page` (可选): 页码，默认为 1。
- **示例:** `https://api.furrynovel.ink/pixiv/novels/recent/cache?page=2`
- **响应:** 返回一个小说对象组成的数组。
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/novels/recent/cache?page=1`，仅展示前 3 条):**
  ```json
  [
    {
      "id": "26259641",
      "title": "LINPX x口袋英雄 盲盒飞机杯征文企划",
      "userName": "自然可可",
      "tags": [
        "furry",
        "米诺忒斯",
        "征文比赛"
      ],
      "length": 492,
      "createDate": "2025-10-22T21:29:39+09:00",
      "seriesId": null,
      "seriesTitle": null
    },
    {
      "id": "26428468",
      "title": "神秘出手赤龙不会遇到第五人格煌黑(事实上里面不包含一点第五人格成分)",
      "userName": "明月伴我行",
      "tags": [
        "R-18",
        "兽人",
        "龙",
        "同性向",
        "纯爱",
        "龙兽人",
        "第五人格含量0"
      ],
      "length": 12347,
      "createDate": "2025-11-10T15:57:29.000Z",
      "seriesId": null,
      "seriesTitle": null
    },
    {
      "id": "26425002",
      "title": "亚龙的后宫(四)",
      "userName": "瓦尔西斯",
      "tags": [
        "R-18",
        "R18",
        "偷窥",
        "玩具",
        "嘲吹",
        "怀孕",
        "产卵",
        "大量射精",
        "下克上"
      ],
      "length": 14634,
      "createDate": "2025-11-10T10:21:58.000Z",
      "seriesId": null,
      "seriesTitle": null
    }
  ]
  ```

#### 1.4 获取小说评论
获取指定小说的评论。

- **方法:** `GET`
- **Endpoint:** `/pixiv/novel/{novelId}/comments`
- **路径参数:**
    - `{novelId}` (必填): 小说的 ID。
- **示例:** `https://api.furrynovel.ink/pixiv/novel/12345678/comments`
- **响应:** 结构未知，但应包含评论列表。
- **实际响应 (`GET https://api.furrynovel.ink/pixiv/novel/26259641/comments`):** 截至 2025-11-11，该接口返回 HTTP 418，正文如下，表明需要签名才能访问：
  ```json
  {
    "error": "sign used"
  }
  ```

---

### 2. 系列 (Series)

#### 2.1 获取系列小说详情
获取指定系列 ID 的详细信息，包含系列介绍和其下所有小说的列表。

- **方法:** `GET`
- **Endpoint:** `/pixiv/series/{seriesId}/cache`
- **路径参数:**
    - `{seriesId}` (必填): 系列的 ID。
- **示例:** `https://api.furrynovel.ink/pixiv/series/12345/cache`
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/series/13987415/cache`，仅包含前 2 篇小说):**
  ```json
  {
    "title": "我在异世界当公交车（重制版）",
    "caption": "这个来自于群友的强烈建议，也是我连载最多的那个时候。很多时候，我总是半途而废，这次也许也坚持不了那么长的时间，但是看到popi老师连载了那么多。他再度唤起了我的当初的理想，为什么他可以坚持那么长的时间，而我却连过百的章节都没有？靠着那么一点点的不甘心，我将剧情直接重置并重写了，这次有群友们的支持，一定要坚持坚持更长时间啊，直到给出一个可以的尚可的大结局。\n这一次，我将一周放出一次，每次放出五章，每次2000字左右。\n剧情的话还是沿用老的，一个人穿越异世界享受兽人老公的性福生活（主线），但是在这之外我还会探索更多的可能性和更多的人物，也许还会有女性配角出现（没错说的就是你伊莲），在异世界里，享受的同时，去揭开更多的秘密吧！",
    "userName": "猞猁武士",
    "tags": [
      "兽人",
      "GAY",
      "R18",
      "furry",
      "剧情",
      "异世界",
      "男同",
      "纯爱",
      "绿帽",
      "日常"
    ],
    "total": 18,
    "novels": [
      {
        "id": "25092275",
        "title": "1~5 章",
        "coverUrl": "https://i.pximg.net/c/150x150_80/novel-cover-master/img/2025/06/19/00/31/47/sci13987415_231b126d6016569ff775baa8f5b05175_master1200.jpg",
        "tags": [
          "R-18",
          "兽人",
          "GAY",
          "R18",
          "furry",
          "剧情",
          "异世界",
          "男同",
          "纯爱",
          "绿帽"
        ],
        "userId": "53641243",
        "pixivLikeCount": 539
      },
      {
        "id": "25152716",
        "title": "6~10 章",
        "coverUrl": "https://i.pximg.net/c/150x150_80/novel-cover-master/img/2025/06/19/00/31/47/sci13987415_231b126d6016569ff775baa8f5b05175_master1200.jpg",
        "tags": [
          "R-18",
          "兽人",
          "GAY",
          "R18",
          "furry",
          "剧情",
          "异世界",
          "纯爱",
          "绿帽",
          "日常"
        ],
        "userId": "53641243",
        "pixivLikeCount": 141
      }
    ]
  }
  ```

---

### 3. 用户 (Users)

#### 3.1 批量获取用户详情
通过用户 ID 列表，一次性获取多位用户的详细信息及其作品列表。

- **方法:** `GET`
- **Endpoint:** `/pixiv/users/cache`
- **查询参数:**
    - `ids[]` (必填): 用户 ID 数组。
- **示例:** `https://api.furrynovel.ink/pixiv/users/cache?ids[]=98765&ids[]=54321`
- **响应:** 返回一个用户对象组成的数组。每个用户对象包含其发布的小说 ID 列表。
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/users/cache?ids[]=3462850&ids[]=76767755`，每位用户仅保留前 5 篇作品和前 4 个标签):**
  ```json
  [
    {
      "id": "3462850",
      "name": "自然可可",
      "comment": "Nice to meet you! 只有清水可以吗？",
      "imageUrl": "https://i.pximg.net/user-profile/img/2021/04/01/02/49/55/20455516_d82e9f4cc5bdc4bfbf509c9f36cf4e27_170.png",
      "novels": [
        "14962917",
        "15264482",
        "15428356",
        "15824794",
        "15826174"
      ],
      "tags": [
        {
          "tag": "清水",
          "time": 6
        },
        {
          "tag": "实验性",
          "time": 4
        },
        {
          "tag": "二次創作",
          "time": 1
        },
        {
          "tag": "讽刺",
          "time": 1
        }
      ]
    },
    {
      "id": "76767755",
      "name": "明月伴我行",
      "comment": "建了一个小群，可以进来玩252578796",
      "imageUrl": "https://s.pximg.net/common/images/no_profile.png",
      "novels": [
        "22033955",
        "22229453",
        "22326737",
        "23623514",
        "24775441"
      ],
      "tags": [
        {
          "tag": "兽人",
          "time": 5
        },
        {
          "tag": "龙",
          "time": 5
        },
        {
          "tag": "纯爱",
          "time": 5
        },
        {
          "tag": "同性向",
          "time": 2
        }
      ]
    }
  ]
  ```

#### 3.2 获取推荐用户
获取推荐用户列表。

- **方法:** `GET`
- **Endpoint:** `/fav/user/cache`
- **示例:** `https://api.furrynovel.ink/fav/user/cache`
- **响应:** 返回一个包含用户 ID 和其他信息的用户对象数组。
- **响应示例 (`GET https://api.furrynovel.ink/fav/user/cache`，仅展示前 5 条):**
  ```json
  [
    {
      "_id": "78118824",
      "id": "78118824",
      "name": "未知人士",
      "_time": 1758240576322,
      "_date": "2025-09-19T00:09:36.322Z"
    },
    {
      "_id": "12451531",
      "id": "12451531",
      "name": "枝无儚",
      "_time": 1758240576322,
      "_date": "2025-09-19T00:09:36.322Z"
    },
    {
      "_id": "90683262",
      "id": "90683262",
      "name": "晋河君",
      "_time": 1758240576322,
      "_date": "2025-09-19T00:09:36.322Z"
    },
    {
      "_id": "713547",
      "id": "713547",
      "name": "夜の星",
      "_time": 1758240576322,
      "_date": "2025-09-19T00:09:36.322Z"
    },
    {
      "_id": "56795567",
      "id": "56795567",
      "name": "在逃蓝莓酱（接稿中）",
      "_time": 1758240576322,
      "_date": "2025-09-19T00:09:36.322Z"
    }
  ]
  ```

---

### 4. 搜索 (Search)

#### 4.1 搜索小说
根据关键词搜索小说。

- **方法:** `GET`
- **Endpoint:** `/pixiv/search/novel/{keyword}/cache`
- **路径参数:**
    - `{keyword}` (必填): 搜索的关键词，需要进行 URL 编码。
- **查询参数:**
    - `page` (可选): 页码，默认为 1。
- **示例:** `https://api.furrynovel.ink/pixiv/search/novel/%E5%85%BD%E4%BA%BA/cache?page=1`
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/search/novel/%E5%85%BD%E4%BA%BA/cache?page=1`，仅展示前 2 条):**
  ```json
  {
    "total": 10965,
    "novels": [
      {
        "id": "26432511",
        "title": "第二部第五章 医药世家的堕落——周明德一家淫堕（上）（高H，超长篇）",
        "userName": "菲尔德",
        "tags": [
          "R-18",
          "NTR",
          "触手",
          "兽人",
          "药渍",
          "调教",
          "秩序破坏",
          "脑奸",
          "哥布林",
          "寝取"
        ],
        "length": 11948,
        "seriesId": "14533533"
      },
      {
        "id": "26430847",
        "title": "第八章：光明重燃与庆功宴",
        "userName": "tmtsdust",
        "tags": [
          "中文",
          "gay",
          "兽人",
          "男同",
          "同人"
        ],
        "length": 7388,
        "seriesId": "14890796"
      }
    ]
  }
  ```

#### 4.2 搜索用户
根据用户名搜索用户。

- **方法:** `GET`
- **Endpoint:** `/pixiv/search/user/{username}/cache`
- **路径参数:**
    - `{username}` (必填): 搜索的用户名，需要进行 URL 编码。
- **示例:** `https://api.furrynovel.ink/pixiv/search/user/SomeAuthor/cache`
- **响应示例 (`GET https://api.furrynovel.ink/pixiv/search/user/%E8%87%AA%E7%84%B6/cache`，仅展示前 2 条):**
  ```json
  {
    "total": 3,
    "users": [
      {
        "id": "3462850",
        "name": "自然可可",
        "comment": "Nice to meet you! 只有清水可以吗？",
        "novels": [
          "26259641",
          "25267864"
        ]
      },
      {
        "id": "10610297",
        "name": "心中有曲自然嗨",
        "comment": "",
        "novels": []
      }
    ]
  }
  ```
