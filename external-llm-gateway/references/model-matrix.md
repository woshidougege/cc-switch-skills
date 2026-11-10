# 模型能力实测记录（WorkBuddy2API 网关）

> 实测日期：2026-11-03 ｜ 网关 workbuddy2api-hub v1.10.7 ｜ 端点 `http://127.0.0.1:8788/v1`
> 方法：19 个模型 × 图/音/视 = 57 次调用（max_tokens 64）+ 复测 38 次（max_tokens 3000，抓 content / reasoning_content / usage）

## 1. 网关 /v1/models 原始清单

19 个模型，**全部只声明 `input_modalities = text,image`**，没有一个声明 audio 或 video：

~~~
hy4-preview, hy3, deepseek-v4.1-flash, glm-5.3, glm-5.3-flash, glm-5.2, glm-5.1,
glm-5v-turbo, minimax-m3, kimi-k3-1, kimi-k2.8-preview, kimi-k2.7, kimi-k2.6,
deepseek-v4-pro, space-bunny, minimax-m3.1-flash, kimi-k3.1-pro, step-5-preview, mimo-v2.6-pro
~~~

## 2. 音频：0/19 全部失败

所有模型统一报错（来自上游协议解析，不是模型能力问题）：

~~~
upstream 400: code 11101, msg: Parse message failed: unsupported content type at index 0: input_audio
~~~

**网关层就不透传 `input_audio`**，换任何模型都没用。想走音频只有三条路：
1. 本地 faster-whisper 转写后喂文本；
2. 改网关源码；
3. 申请小米开放平台 `MIMO_API_KEY` 直连官方 API。

## 3. 图片：17/17 成功（2 个撞 429）

全部模型都能看 `data:image/jpeg;base64`，描述质量都不错（能读出 Teams/Zoom 屏幕共享 + 紫色调 dashboard + 参会人面板）。
失败的 2 个是 `glm-5.3`、`kimi-k3-1`，原因都是 429 账号池冷却，不是模态问题。

## 4. 视频：只有 3/19 真能看

### 4.1 能看（给的是屏幕实况描述）

| 模型 | 原文摘录 |
|---|---|
| **minimax-m3** | A screen-shared web browser shows a purple-themed business dashboard with a white background. The dashboard contains a top navigation bar, a row of small KPI cards, a purple horizontal chart, a donut chart on the left, a central stacked bar chart in purple, orange, and green, and a table of many rows. |
| minimax-m3.1-flash | The video shows a screen-shared web browser displaying a business analytics or reporting dashboard. A small label at the bottom-left indicates that the screen is being shared. |
| space-bunny | The screen shows a video-conferencing session with a shared browser window taking up most of the screen. A web-based analytics or management dashboard is open in a browser. It has a clean white-and-light-gray interface with purple accents and a dark purple header. |

### 4.2 看不了（模型自述，原文摘录）

| 模型 | 原文摘录 |
|---|---|
| **mimo-v2.6-pro** | I am not able to describe video content — I can only process text and images (not videos). |
| deepseek-v4.1-flash | the current model does not support videos, and the content has been filtered |
| deepseek-v4-pro | the current model does not support video or visual content |
| hy3 | the current model does not support video input |
| hy4-preview | The current model is text-only and does not support video or image input ... the visual content attached to your message was filtered out before it reached me |
| glm-5.2 | As a text-based AI model, I do not have the ability to view screens, videos, or visual media |
| glm-5.3-flash | I do not have multimodal capabilities in this session |
| glm-5v-turbo | As a text-based AI model, I do not have the capability to process visual media such as videos or images |
| kimi-k2.6 | the current model does not support video or visual content processing, and the content has been filtered |
| kimi-k2.7 | As a text-only model, I do not have the ability to view images, video feeds, or screen content |
| kimi-k2.8-preview | video content is not supported by this model and has been filtered out |
| kimi-k3-1 | I can not view or analyze the video in this environment |
| kimi-k3.1-pro | the current model does not support video input |
| step-5-preview | The system has flagged that the current model does not support videos |

### 4.3 未判定

- `glm-5.3`：两次都 429 `every usable account in realm cn is cooling the upstream glm-5.3 window`
- `glm-5.1`：400 `the reasoning effort value is not supported by the current model`（payload 问题，去掉 reasoning 参数可重测）

## 5. 判定陷阱（重测时必看）

自动判定会**误报**：`kimi-k3-1`、`kimi-k3.1-pro`、`mimo-v2.6-pro` 的回复里用的是弯引号 can’t（U+2019），ASCII 正则匹配不到，被误标为 SAW-IT。人工核对后三者都是「看不到」。

**正确做法**：判定前先把 U+2017–U+201F 统一替换成 ASCII 引号，或者干脆读全文人工确认。`probe_models.py` 的 `looks_like_deny()` 已内置这个替换。

## 6. 直连小米官方 API 的验证

拿 WorkBuddy 的 key 打 `https://api.xiaomimimo.com/v1/chat/completions`：

~~~
api-key: <key>         => HTTP 401 {"error":{"message":"Invalid API Key","code":"401","type":"invalid_key"}}
Authorization: Bearer  => HTTP 401 同上
~~~

**网关 key 与小米官方 key 不通用**，不能绕开网关。

## 7. 小米官方 API 规格（备用，待申请 key）

| 项 | 值 |
|---|---|
| base_url | `https://api.xiaomimimo.com/v1` |
| 鉴权 | header `api-key: <MIMO_API_KEY>` |
| 视频块 | `{"type":"video_url","video_url":{"url":"<URL 或 data:video/mp4;base64,...>"},"fps":2,"media_resolution":"default"}` |
| 视频限制 | URL 方式单文件 ≤300MB；base64 方式编码串 ≤50MB |
| 音频块 | `{"type":"input_audio","input_audio":{"data":"<URL 或 base64>"}}`，≤100MB |
| mimo-v2.6-pro | 全模态，context 1M，output 128K，RPM 100，TPM 10M |
| mimo-v2.5-asr | 语音识别专用，context 8k，output 2k |

文档索引：<https://mimo.mi.com/llms.txt>；各页是静态 markdown，形如 `https://mimo.mi.com/static/docs/quick-start/**.md`

## 8. 测试素材（可复用）

都在 `C:\Users\63588\lenovo\ssg-sales-ops\.tmp\service-portfolio\`：

| 文件 | 大小 | 说明 |
|---|---|---|
| test_video.mp4 | 45966 B | 8 秒 480p 带音轨（从录屏 2000s 处切） |
| test_audio.wav | 256078 B | 8 秒 16k 单声道 |
| test_image.jpg | 34106 B | 640 宽截图 |

## 9. 测试脚本存档

同目录下：`mimo_modality_test.py`（57 次模态测试）、`mimo_video_retest.py`（38 次复测）、`mimo_direct_test.py`（直连官方 API 验证）、`mimo_probe.py` / `mimo_models.py`（端点与模型探测）。
