# 网关版本变更摘要（v1.10.1 → v1.10.7）

> 整理日期 2026-11-03 ｜ 依据：本机 README.md 的 Changelog 段 + 官方 README 对比 + 全量 py 文件 diff + `/health` 与 `/v1/media/models` 实测
> 注意：README 里指向的 `docs/CHANGELOG.md` **不在绿色包内**（只存在于 GitHub 仓库），所以 v1.10.2 / v1.10.3 的细节在本地查不到，只能看代码 diff。

## 一句话总结

**这 6 个版本对「调用聊天模型」几乎没有影响** —— 模型目录一个没变，仍是同样 19 个，仍然只有 3 个能看视频、0 个能听音频。
真正的变化三块：① 新增生图/生视频媒体接口（默认关闭）；② CodeArts 第三出口补齐自动签到与计费修复；③ 一批稳定性修复（SSE 心跳、保活提前量、看板交互）。

## 逐版变更

| 版本 | 主要变更 | 对调用方的影响 |
|---|---|---|
| **v1.10.7** | 国内版 `deepseek-v4.1-flash` 计费与出站路由修复（#748）；CodeArts 每日签到按活动类型识别 + 可选自动签到（#747） | 用 deepseek-v4.1-flash 的账目与路由变准；模型列表无变化 |
| **v1.10.6** | 生图 / 异步生视频媒体能力集成（#728）；并发日志原子追加加固；设置页二级分类胶囊导航 | 新增一整套 /v1/images/* 、/v1/videos/* 接口，默认关闭 |
| **v1.10.5** | 国际版 DeepSeek 免费通道恢复 + 出站节点切换；Codex 首段脱敏去指纹修复与出口归因（#743/#744）；glm-5.1 推理档位自动补齐防 11150（#742）；临期积分优先权重按剩余积分对数优化（#741） | glm-5.1 报 reasoning effort 400 的问题修了；账号调度更偏向快过期积分 |
| **v1.10.4** | 成长中心全能引擎与 Buddy 盲盒扩展；补齐 6 项官方新任务；解除资料库/桌面对话跳过限制；微信小程序链式任务（Sequential_Tasks_1~6 / 校园日） | 纯刷积分相关，与对话调用无关 |
| **v1.10.3** | 本地无记录；代码 diff 显示 wb_proxy.py +83KB、wb_tasks.py +18KB | 无对外接口变化 |
| **v1.10.2** | 本地无记录；代码 diff 显示 | 无对外接口变化 |
| **v1.10.1**（旧基线） | 429 响应带绝对恢复时刻（#720）、工具名校验防 11133（#726）、CodeArts 会话头修并发上限（#723）、代理槽账密认证（#648） | — |

## 1. 最重要：新增媒体能力（v1.10.6）

### 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/images/generations` | 文生图，OpenAI Images 形状，默认关闭 |
| POST | `/v1/images/edits` | 改图 / 图生图；image 只接受 data URL 或公网 http(s)，传本地路径会把服务器上的文件发给上游 |
| POST | `/v1/videos` | 提交文生/图生视频，立刻 202 + task id；?wait=1 阻塞到完成；并发满时先排队（不扣积分，返回 queue_position） |
| GET | `/v1/videos/{id}` | 查任务状态（queued / in_progress / completed / failed） |
| GET | `/v1/videos/{id}/content` | 下载 mp4，支持 ?t= 签名令牌 |
| GET | `/v1/media/tasks` | 最近生视频任务与队列统计（每个 Key 只看自己的） |
| GET | `/v1/media/models` | 可用的生图/生视频模型与约束 |

### 可用模型（本机实测 /v1/media/models，enabled: false 当前关闭）

| 模型 ID | 类型 | 规格 |
|---|---|---|
| `hunyuan-image-alpha` | text-to-image | 约 6 积分 / 张 |
| `hunyuan-image-alpha-edit` | image-to-image | 约 6 积分 / 张 |
| `kling-video-v3` | text-to-video / image-to-video | 3–15 秒，720P / 1080P / 4K，16:9，音频可开关 |
| `minimax-video-h3` | text-to-video / image-to-video | 4–15 秒，768P / 2K |

### 成本护栏（默认值）

- 单张图约 **5.7–6 积分**，一条 5 秒视频 **57–129 积分** —— 比聊天 token 贵一个量级
- `image_max_per_minute = 6`（每 Key 每分钟），上限 60
- `video_max_seconds = 15`，上限 60
- `video_concurrency = 3`，上限 8，超出排队
- `daily_credits_per_key = 0` = 不限（有意为之：不替用户决定花多少）
- 媒体并发槽 4
- **媒体接口不幂等，超时不要自动重试**（会重复扣积分）

### 怎么开

看板 http://127.0.0.1:8788/ → 设置页 → 媒体能力 → 打开总闸。关闭时这些路由直接 404（不是 403），少一个探测面。

## 2. CodeArts 第三出口（v1.10.7 重点）

- 签到判据从硬编码 campaignId 改成按活动类型识别：`CHECKIN_CAMPAIGN_TYPES = ("USER_LOGIN",)`，注释理由——campaignId 每换季都会变（2026-10 是 34），所以按类型挑，不按 id 硬编码。保留历史 id `(1, 4)` 兼容老账号
- 新增 `credits_auto_claim` 开关（默认 False），真领积分在后台线程跑，锁外触发
- OAuth 回调同时认 ticket_id 与 state 两个参数名（华为云会把 ticket_id 改写成 state），只认 ticket_id 会让浏览器回调全部失败
- 本机 /health 显示 codearts.configured: false —— 尚未启用该出口

另外补一句：glm-5.1 的 400（the reasoning effort value is not supported）在 v1.10.5 #742 里修了，但实测时仍报过一次，可能是调用时 payload 仍带 reasoning 参数所致。

## 3. 稳定性修复（与调用相关）

| 修复 | 内容 | 对你的意义 |
|---|---|---|
| **SSE 心跳** | 上游思考期间可能一个字节都不发，客户端误判断流。Chat / Responses / Anthropic 三条流式路径共用后台 SSEHeartbeat，每 15 秒无写入就发 `: keepalive` 注释帧 | 长思考模型的流式不再莫名断开 |
| **Token 保活提前量 2h → 48h** | 原来每天 22:00 巡检一次、只续剩余不足 2 小时的，导致 23/24 的到期时刻都在过期后才发现，账号期间全部 401。现在默认 48 小时（大于 24h 巡检间隔），可用 WB_KEEPALIVE_LEAD_HOURS 调 | 账号 401 中断大幅减少；拿不到到期时间的账号也会照常续期 |
| **调度器读错模块副本** | python wb_proxy.py 启动时主模块是 __main__，import wb_proxy 会再加载一份副本（LOG_STORE 为 None），导致 6.4 万行日志里 [调度器] 0 条、区域连锁暂停闸门恒为 0 | 统一走 _proxy_module() 取正在运行的那份 |
| **keep-alive 失步** | 面板按钮 POST 空 {} 而路由不解析，两个字节留在 socket，下一个请求变成 {}GET /usage 被回 501，面板闪「无法连接反代」 | 面板不再误报断开 |
| **签到误判成功** | ok: (code == 0 or code == 10001) 无条件成功，把「请求处理中，请勿重复操作」也记成成功还写了 lastCheckin，导致当天不再重试。现在按文案分 checked / already / pending / failed 四类 | 积分任务成功率变准 |
| **网页活跃建会话失败退避** | 建会话 5xx 只用几百毫秒，旧实现立刻重打，回退组合开着时一秒内打光所有候选。现在按 phase（create / session / turn）区分，create 失败补指数退避（默认 5 秒，上限 30 秒，设置页可改，填 0 = 不退避） | 上游抖动不再让整批账号全灭 |
| **临期积分权重** | 从「按紧迫度」改为「紧迫度 × 剩余量」的对数加权，EXPIRY_WEIGHT_SCALE = 10，最急的号约拿 5 倍流量而不是独占 | 快过期的积分更不容易浪费 |
| **面板登录闸门 fail-closed** | 首帧会闪一下空看板；?pwd= 密码错直接卡死。现在默认 display:flex，只有本标签已有令牌才由 head 同步脚本隐藏 | 面板体验修复 |
| **自绘下拉框** | 原生 select 展开层 CSS 够不着（深色主题下白框刺眼），运行时增强：自绘面板 + 键盘 + aria 语义，原生元素保留 | 纯 UI |
| **会员档位胶囊** | 账号行显示 Free / 体验版 胶囊 | 一眼看出哪些号是免费档 |

## 4. 代码层面动过的文件（v1.10.1 → v1.10.7）

```
wb_accounts.py      265810 -> 272919  (+7109)
wb_catalog.py        55250 ->  55363  (+113)
wb_codearts.py       89884 ->  98320  (+8436)
wb_entitlements.py      NEW
wb_media_client.py      NEW
wb_media_tasks.py       NEW
wb_media.py             NEW
wb_modelsdev.py       8644 ->   8981  (+337)
wb_pricing.py        97355 -> 101430  (+4075)   <- 新增 deepseek-v4.1-flash-sg 等定价条目
wb_proxy.py        1135051 -> 1218857 (+83806)  <- 媒体路由 + SSE 心跳 + keep-alive 修复
wb_scheduler.py      37503 ->  38438  (+935)    <- 猫猫旅行 / Buddy 盲盒调度
wb_settings.py      125510 -> 132256  (+6746)   <- MEDIA_DEFAULTS / MEDIA_LIMITS
wb_tasks.py          46203 ->  64914  (+18711)  <- 小程序链式任务 + 动态专家
wb_usage_io.py          NEW
```

README 也变了：测试套件从 **246 个（183 Python + 63 JS）** 增加到 **259 个（196 Python + 63 JS）**；看板顶部页签从 6 个变成 7 个（新增「任务与福利」「媒体」）。

## 5. 对现有调用方式的影响 —— 结论

| 项目 | 变了吗 |
|---|---|
| /v1/models 返回的 19 个聊天模型 | **没变**（逐个比对，完全一致） |
| 图片 image_url 支持 | 没变，仍 19/19 |
| 音频 input_audio 支持 | **仍然 0/19**，网关照样不透传 |
| 视频 video_url 支持 | 仍只有 minimax-m3 / minimax-m3.1-flash / space-bunny 三个能看（glm-5.3-flash 现在只声明 text） |
| chat/completions 与 responses 协议 | 没变 |
| API Key | 没变，仍只对 127.0.0.1:8788 有效 |
| 新增能力 | **生图 / 生视频**（默认关闭）、/health 更详细、SSE 心跳、保活 48h |

> 所以：**原先 external-llm-gateway skill 的全部结论仍然有效**，不需要改任何调用代码。这次升级只是多了媒体接口和一批稳定性修复。

## 6. 升级本身（本机发生了什么）

- wb-proxy/updates/status.json：{"state":"succeeded","version":"1.10.7","message":"已更新到 1.10.7","updated_at":"2026-11-03 16:57:37"}
- 升级前自动备份到 wb-proxy/updates/backup-1.10.7/（该备份 backup.json 的 absent 列出 wb_media.py、wb_media_client.py、wb_media_tasks.py、wb_usage_io.py，证明这 4 个文件是升级时新增的）
- 根目录仍是 WorkBuddy-Portable-v1.7.29-FullConfig-20261023（目录名是打包版本，不代表内部版本）
- /health 实测：16 个账号（cn 14 + intl 2），就绪 14 个（全部 cn），accounts_ready_by_realm.intl = 0 —— **国际版目前没有可用账号**

## 7. 要不要做什么

1. **什么都不用做** —— 现有调用不受影响。
2. 想试生图/生视频：看板设置页打开媒体总闸，注意单张 6 积分、5 秒视频 57–129 积分，与聊天 token 成本不是一个量级；且媒体接口不幂等，超时别重试。
3. 若某些模型突然 429 或「该区没有可用账号」：先看 /health 的 accounts_ready_by_realm，国际版 0 → 只有 cn 出口的号。
4. docs/CHANGELOG.md 里 v1.10.2 / v1.10.3 的细节只能去 GitHub 仓库看，绿色包里没有。
