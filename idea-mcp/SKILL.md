---
name: idea-mcp
description: 主工作区使用 IntelliJ IDEA 的构建、运行和调试通道；worktree 使用 PowerShell mvn。IDEA MCP 禁止文件写入和 VCS/MR/worktree 操作。
metadata:
  short-description: 主工作区 IDEA 构建、运行与调试
---

# IDEA MCP：构建、运行与调试通道

本 Skill 负责主工作区的 IntelliJ IDEA 构建、运行和调试能力。worktree 无法可靠调用 IDEA，必须改用 PowerShell `mvn`。IDE MCP 不是文件编辑工具，也不是 Git/MR 工具。

## 职责边界

适用：

- 构建项目或指定文件，并读取构建输出。
- 启动、停止、检查和恢复运行/调试会话。
- 设置断点或 logpoint，读取调用栈、变量和 console 输出。
- 查看和管理 IDEA run/debug configuration。

禁止：

- 使用 IDEA MCP 创建、读取、修改、移动、重命名或删除文件。
- 使用 IDEA MCP 执行 branch、commit、cherry-pick、merge、push、MR、worktree 或部署操作。
- 用 IDEA MCP 承担项目业务规则判断。

文件操作优先级：

1. Codex 当前会话提供的原生文件工具。
2. 原生文件工具不可用时，使用 PowerShell。
3. 不得退回到 IDEA MCP 文件接口。

分支、提交、MR、worktree 和部署统一由主 Agent 及 `ssg-sales-ops-branch-workflow` 管理，本 Skill 不重复或改写这些规则。

## 工作区与工具选择

### 主工作区

1. 主工作区优先使用当前会话中实际可发现的 native IDE MCP 工具；不要写死工具前缀或名称。
2. native IDE MCP 缺失、报错或返回 `unsupported call` / `Unsupported` / unknown tool 时，降级到本地 HTTP wrapper。
3. 一旦降级，本任务后续保持在 wrapper 通道，不要来回切换。
4. 降级时在下一条用户可见消息中说明一次，例如“native IDE MCP 不可用，改用 idea-mcp wrapper”，然后继续。
5. wrapper 也不可用时，build/run/debug 停止并报告阻塞；是否允许主工作区改用 `mvn` 先征得用户确认。

### Worktree

- worktree 无法可靠调用当前 IDEA 项目，不允许假装通过 IDEA 构建。
- worktree 的构建/测试使用 PowerShell 执行项目所需的 `mvn` 命令；这是正常且必要的路径，不要因“必须用 IDEA”而停止。
- 执行前确认当前目录确实是目标 worktree 和正确模块，优先只构建受影响模块，并保留原始输出。

## 调用 wrapper

```powershell
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py --list [substring] --project '<ABS_PROJECT_PATH>'
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py TOOL_NAME '{"arg":"value"}' --project '<ABS_PROJECT_PATH>' --timeout SEC
```

规则：

- 必须使用当前任务工作区根目录，或显式传入正确的 `--project '<ABS_PROJECT_PATH>'`。
- 不得省略 `--project` 而静默使用 wrapper 的固定默认项目路径。
- `ARGS_JSON` 必须是 JSON object；除工具另有说明外，其中的路径按 IDEA 项目根目录解析。
- 默认 timeout 为 90 秒；`WAIT_FOR_PAUSE` 或长构建可提高到 180 秒。
- PowerShell 中始终用单引号包裹 JSON，并保持单行。
- wrapper 输出未包装的工具结果 JSON；失败时 exit code 为 1 并返回 `{"error": ...}`。
- wrapper 每次调用创建独立 session；轮询必须设置上限。

## Recipes

```powershell
$project = 'C:\absolute\path\to\project'

# 查看是否存在调试会话
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_get_debugger_status '{}' --project $project

# 优先使用不中断程序的 logpoint
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_set_breakpoint '{"filePath":"smartop-service/admin/src/main/java/com/lenovo/admin/chat/controller/ChatController.java","line":30,"suspendPolicy":"NONE","logExpression":"chatMsg"}' --project $project
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_control_session '{"action":"DRAIN_EVENTS"}' --project $project

# 会暂停程序的调试往返
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_set_breakpoint '{"filePath":"<rel-path>","line":123}' --project $project
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_control_session '{"action":"RESUME"}' --project $project
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_control_session '{"action":"WAIT_FOR_PAUSE","timeout":120000}' --project $project --timeout 150
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_get_stack '{}' --project $project
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py xdebug_get_frame_values '{"depth":1}' --project $project

# 构建改动文件并读取真实错误
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py build_project '{"filesToRebuild":["smartop-service/admin/src/main/java/com/lenovo/admin/chatbi/service/ChatbiTrackingService.java"]}' --project $project
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py get_build_output '{}' --project $project

# 读取运行中的 console 输出
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py get_console_output '{}' --project $project
```

## 并发与子 Agent

- 同一 IDEA 实例同一时间只允许一个构建或一个调试变更操作。
- 多个子 Agent 不得同时运行 build、设置/删除断点、resume/pause 或控制同一个调试会话。
- 主 Agent 必须先指定唯一的 build/debug owner 和互斥范围，再允许子 Agent 使用 IDEA MCP。
- 只读侦察可由多个子 Agent 并行，但不得调用会改变 build/debug 状态的工具。
- 子 Agent 的 IDE 结论只作为输入；最终构建、调试结论和用户汇报由主 Agent 复核。

## 安全与错误处理

- Read-only first：先检查 debugger/build 状态，再执行会改变状态的操作。
- IDEA 必须正在运行且已打开目标项目；否则调用会失败。
- 同一时间只维护一个调试会话；存在多个 session 时必须显式传入 `sessionId`。
- 不通过本 Skill 执行任何 VCS、远程状态变更、MR、worktree 或部署动作。
- 工具错误以 JSON 返回时，先展示并分析错误；同一调用连续失败 3 次后停止并报告。
- wrapper 仅连接本机 `127.0.0.1:64515`，不得暴露该端点或提交任何凭据。
- 不把本地调试凭据、请求头、token 或临时产物写入仓库。