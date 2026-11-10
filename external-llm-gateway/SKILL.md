---
name: external-llm-gateway
description: 当 DSH 内置能力不够用时（识别录屏/视频画面、识别音频、超长上下文、多模型交叉验证、更强推理），通过本机 WorkBuddy2API 网关调用外部大模型补上。核心约束：其他模型计费，调用前必须告诉用户用哪个模型、为什么、预计多少 token；小规模测试免申请直接跑，大规模调用要先申请、用户同意后才执行。
whenToUse: 任务需要 DSH 自身工具做不到的能力——识别视频/录屏画面、识别音频、需要 1M 级上下文、需要多个模型交叉验证结论、或用户明确说「用网关」「用外部模型」「试试别的模型」时。
---

# 外部大模型调用（WorkBuddy2API 网关）

> 一句话：DSH 干不了的活，用本机网关调外部模型补上。**但每次调用都要让用户知道用哪个模型、花多少**。

## 一、三条铁律（费用与授权）

外部模型是**计费 / 计积分**的，不同模型价格差很多，所以：

| 场景 | 要不要申请 | 怎么做 |
|---|---|---|
| **小规模测试** | **不用申请** | 单次请求 ≤ 5K token 且总调用 ≤ 3 次。直接跑，跑完在结果里注明「本次用 <模型名>，<N> tokens」 |
| **常规调用** | **要申请** | 先报四项：① 模型名 ② 选它的理由 ③ 预计请求次数 ④ 预计 token 量。等用户回「可以 / 同意 / go」再执行 |
| **大批量 / 视频 / 循环** | **要申请，且给完整计划** | 例如整段录屏分片识别，要列：分片数、每片大小、单片 token 估算、总 token、总耗时 |

**无论免不免申请，都必须在结果里注明用的是哪个模型、消耗了多少 token。**

- 用户指定模型时，严格用指定的，不要擅自替换。
- 用户没指定时，先按「第四节 能力矩阵」选最小够用的模型，并说明为什么选它。
- 不确定要不要申请时，**问一下**，不要先跑。

## 二、网关信息

| 项 | 值 |
|---|---|
| Base URL | `http://127.0.0.1:8788/v1` |
| 鉴权 | `Authorization: Bearer <key>`（也接受 `api-key: <key>`） |
| API Key | `0f60f86cfdf4f77173af1cd48af15f8bd544` |
| 端点（聊天） | `GET /v1/models`、`POST /v1/chat/completions`、`POST /v1/responses` |
| 端点（媒体，v1.10.6 新增，**默认关闭**） | `POST /v1/images/generations`、`POST /v1/images/edits`、`POST /v1/videos`（立刻 202 + task id，`?wait=1` 阻塞）、`GET /v1/videos/{id}`、`GET /v1/videos/{id}/content`、`GET /v1/media/tasks`、`GET /v1/media/models` |
| 健康检查 | `GET /health`（不用鉴权，返回账号池 / 模型就绪数 / 媒体开关） |
| Web 看板 | `http://127.0.0.1:8788/`（面板密码独立于 API Key，默认 `admin`，可看用量与积分） |
| 项目 | <https://github.com/ardeyouxipianyi/workbuddy2api-hub> v1.10.7 |
| 上游 | 腾讯 workbuddy.ai（国际版）/ codebuddy.cn（国内版） |
| 进程 | `C:\Users\63588\Desktop\WorkBuddy-Portable-v1.7.29-FullConfig-20261023\wb-proxy\python\python.exe` |

**这个 key 只能打本机 8788，打不通小米官方 API**（实测 `api.xiaomimimo.com` 返回 401 Invalid API Key）。不要试图绕过网关直连。

### 协议差异

- `chat/completions`：标准 OpenAI 格式，**推荐用这个**。
- `responses`：OpenAI Responses 格式（给 Codex 用），参数不同（`input` 而不是 `messages`）。
- DSH 里配的 `mimo-v2.6-pro` 走的是 `openai-responses` 协议 + 这个网关。

## 三、⚠️ 风险提示（用之前必须知道）

workbuddy2api-hub 是**非官方客户端**，通过逆向把腾讯 WorkBuddy/CodeBuddy 封装成 OpenAI 兼容接口。项目 README 明确警告：

- **2026-10-23 下午起，上游收紧了对非官方客户端的识别与拦截**；
- 项目已进入**低频维护**，维护者工作压力大，不能保证及时修复；
- 上游可能随时进一步收紧，导致网关不可用；
- **账号可能被限流 / 风控 / 封禁，风险由使用者自行承担**；
- 仅限协议研究与个人自用，**不要用于商业转售、不要共享账号、不要用主账号**。

使用建议：

- 只在 DSH 确实解决不了时用，控制调用频率，不要拿它跑批量压测。
- 网关突然 4xx / 连不上，多半是**上游策略收紧**，不是脚本写错。先看 <http://127.0.0.1:8788/> 面板的状态与流水。
- 积分/额度是**有限资源**，看板里能看到消耗，大调用前可以先看一眼。

## 四、模型能力矩阵（2026-11-03 实测 19 个模型 × 图/音/视，共 95 次调用）

> 网关 `/v1/models` 里**所有 19 个模型都只声明 `input_modalities = text,image`，没有一个声明 audio 或 video**。但实测有 3 个能真的看视频（声明保守）。

### 4.1 三种模态总览

| 模态 | 结果 | 说明 |
|---|---|---|
| **图片** `image_url` | **19/19 全部支持** | `data:image/jpeg;base64,...` 直接可用，描述质量都不错 |
| **音频** `input_audio` | **0/19 全部失败** | 网关不透传。报 `upstream 400: code 11101, msg: Parse message failed: unsupported content type at index 0: input_audio` |
| **视频** `video_url` | **只有 3 个能看** | 其余模型会回「我不能看视频 / 内容被过滤 / 我是纯文本模型」 |

### 4.2 视频能力（关键）

**真能看到视频的 3 个：**

| 模型 | 实测表现 |
|---|---|
| **`minimax-m3`** | 最准：能读出紫色 dashboard、顶部导航、KPI 卡行、环形图、紫橙绿堆叠柱状图、多行表格。**视频首选** |
| `minimax-m3.1-flash` | 能看，描述较细，速度更快 |
| `space-bunny` | 能看，偏场景描述 |

**看不了视频的（模型自己承认）：**
`mimo-v2.6-pro`、`deepseek-v4.1-flash`、`deepseek-v4-pro`、`hy3`、`hy4-preview`、`glm-5.2`、`glm-5.3-flash`、`glm-5v-turbo`、`kimi-k2.6`、`kimi-k2.7`、`kimi-k2.8-preview`、`kimi-k3-1`、`kimi-k3.1-pro`、`step-5-preview`

其中 **`mimo-v2.6-pro` 原话**：`I am not able to describe video content — I can only process text and images (not videos).`
→ DSH 里默认配的那个模型，走网关**看不了视频**，别再试。

**未判定（可补测）：** `glm-5.3`（两次都 429 账号池冷却）、`glm-5.1`（400 `the reasoning effort value is not supported by the current model`，是 payload 问题，去掉 reasoning 参数即可）。

### 4.3 选型速查

| 需求 | 用哪个 | 为什么 |
|---|---|---|
| 看截图 / 界面稿 / 设计图 | `mimo-v2.6-pro` 或 `deepseek-v4.1-flash` | 全部 19 个都能看图，选便宜的 |
| **看录屏 / 视频** | **`minimax-m3`** | 唯一描述准确的 |
| 长文档 / 超长上下文 | `mimo-v2.6-pro`、`deepseek-v4-pro` | 1M context |
| 多模型交叉验证结论 | 并发跑 `deepseek-v4.1-flash` + `glm-5.3-flash` + `kimi-k2.7` | 拿三家答案比对 |
| **听音频 / 转写** | **网关里没有任何模型能做** | 改用本地 faster-whisper（见第六节） |

## 五、怎么调用

### 5.1 最小可运行（Python，只用标准库）

```python
import json, base64, urllib.request

BASE = "http://127.0.0.1:8788/v1"
KEY  = "0f60f86cfdf4f77173af1cd48af15f8bd544"

def call(model, content, max_tokens=1024):
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "max_tokens": max_tokens,
    }).encode("utf-8")
    req = urllib.request.Request(BASE + "/chat/completions", data=body, method="POST")
    req.add_header("Authorization", "Bearer " + KEY)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

# 文本
print(call("deepseek-v4.1-flash", "你好"))
```

### 5.2 传图片

```python
img = base64.b64encode(open("shot.jpg", "rb").read()).decode("ascii")
content = [
    {"type": "text", "text": "描述这张截图里的界面结构和文字"},
    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + img}},
]
print(call("mimo-v2.6-pro", content))
```

### 5.3 传视频（只有 minimax-m3 等 3 个能看）

```python
vid = base64.b64encode(open("clip.mp4", "rb").read()).decode("ascii")
content = [
    {"type": "text", "text": "这段录屏里在讨论什么？界面上有哪些控件和数字？"},
    {
        "type": "video_url",
        "video_url": {"url": "data:video/mp4;base64," + vid},
        "fps": 2,
        "media_resolution": "default",
    },
]
print(call("minimax-m3", content, max_tokens=3000))
```

> **视频大小控制**：base64 后整个请求体会膨胀 1.33 倍。建议先用 ffmpeg 抽成小片（8–30 秒、480p），单片控制在 5MB 以内，否则容易超时或被截断。

### 5.4 现成脚本

```powershell
# 通用调用（文本/图片/视频）
& "C:\Users\63588\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe" `
    "C:\Users\63588\.dsh\skills\external-llm-gateway\scripts\llm_call.py" `
    --model minimax-m3 --video clip.mp4 --prompt "描述这段录屏" --max-tokens 3000

# 列出可用模型 + 能力探测
& "...\python.exe" "C:\Users\63588\.dsh\skills\external-llm-gateway\scripts\probe_models.py"
```

参数见 `scripts/llm_call.py` 顶部注释。

## 六、常见故障与排错

| 现象 | 原因 | 处理 |
|---|---|---|
| `400 unsupported content type at index 0: input_audio` | **网关不透传音频**，不是模型问题 | 改用本地 faster-whisper 转写，再把文本喂给模型 |
| 模型回「我不能看视频 / 内容被过滤 / 我是纯文本模型」 | 该模型确实不支持视频 | 换 `minimax-m3` |
| `429 every usable account in realm ... is cooling` | 账号池冷却 | 等 60 秒重试；不同模型分开试 |
| `400 the reasoning effort value is not supported` | payload 带了该模型不认的 reasoning 参数 | 去掉 reasoning 相关字段 |
| `401 Invalid API Key` | 打的是 `api.xiaomimimo.com` 官方端点 | 只能打本机 `127.0.0.1:8788` |
| 连不上 8788 | 网关进程没起，或上游策略收紧 | 打开 <http://127.0.0.1:8788/> 看面板；或用 `start-wb-proxy.bat` 重启 |
| 请求很久没返回 | 视频/图片太大，或多模态排队 | 缩小输入；必要时 `--timeout` 加大 |

## 七、什么时候用 DSH 自己，什么时候用网关

| 任务 | 优先用 | 说明 |
|---|---|---|
| 看图片 | **DSH 内置 `read_image`** | 本来就支持，不花钱 |
| 读文件 / 跑代码 / 搜网页 | **DSH 内置工具** | 不要用网关代替 |
| 读截图里的小字、密集表格 | 网关多模态 | 原图分辨率高时，模型能读得比我降采样后更细 |
| **看录屏 / 视频** | **网关 `minimax-m3`** | DSH 完全不支持视频输入 |
| **听音频 / 语音转写** | **本地 faster-whisper** | 网关音频全灭；本地免费 |
| 超长文档（>200K token） | 网关 `mimo-v2.6-pro` | 1M context |
| 想交叉验证一个重要结论 | 网关多模型并发 | 拿 2–3 家答案比对 |

## 八、配套文件

- `scripts/config.json` —— 网关地址与 Key，换 Key 只改这里
- `scripts/llm_call.py` —— 通用调用脚本（文本 / 图片 / 视频）
- `scripts/probe_models.py` —— 列模型 + 跑一轮模态探测
- `references/model-matrix.md` —— 19 个模型的完整实测记录与原始报文
- `references/gateway-changelog.md` —— 网关版本变更摘要（v1.10.1 → v1.10.7 补了什么，哪些影响调用）

## 九、实测结论存档（改配置前先看）

- 2026-11-03：19 模型 × 图/音/视 = 57 次 + 复测 38 次。图片 19/19 通过，音频 0/19，视频 3/19。
- **音频那条路是网关层掐断的**（报错来自上游协议解析 `code 11101`），换任何模型都没用。想真正走音频，要么改网关源码让它透传 `input_audio`，要么去申请小米官方 `MIMO_API_KEY` 直连 `api.xiaomimimo.com`（官方支持 `input_audio` 与 `video_url`）。
- 小米官方 API 事实（备用）：base `https://api.xiaomimimo.com/v1`，header `api-key`，视频块 `type=video_url`（URL ≤300MB / base64 串 ≤50MB，带 `fps` 与 `media_resolution`），音频块 `type=input_audio`（≤100MB）。模型 `mimo-v2.6-pro` context 1M / output 128K / RPM 100 / TPM 10M。
