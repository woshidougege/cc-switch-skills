---
name: idea-mcp
description: Fallback driver for the local IntelliJ IDEA over its HTTP MCP wrapper (build, run/debug, breakpoints, run configs, code search, file ops). Use only when the native IDE MCP tools are missing or failing; always prefer the native tools while they work.
metadata:
  short-description: Fallback IDEA control over HTTP MCP
---

# IDEA MCP (via local HTTP wrapper)

IntelliJ IDEA on this machine exposes its MCP companion over streamable HTTP.
Native MCP access is unreliable in this workspace, so call it through
`scripts/idea_mcp.py`, a thin JSON-RPC wrapper (stdlib only, no dependencies).

## Tool priority

1. Prefer the native IDE MCP tools (`mcp__idea__*`) whenever they are available.
2. Fall back to this wrapper only when native tools are missing, error out, or
   return `unsupported call` / `Unsupported` / unknown-tool style failures.
3. Once you have fallen back, stay on the wrapper for the rest of the task
   instead of alternating between the two mechanisms.
4. Announce the fallback once in the next user-facing message
   (for example "IDE MCP 不可用，改用 idea-mcp skill") and keep working —
   do not stop to ask for permission.
5. If the wrapper itself is unavailable, say so and use the terminal for
   read-only or compile commands rather than blocking the task.

## Invoke

```powershell
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py --list [substring]
python C:\Users\63588\.codex\skills\idea-mcp\scripts\idea_mcp.py TOOL_NAME '{"arg":"value"}' [--timeout SEC]
```

- `ARGS_JSON` must be a JSON object; paths are project-relative unless the tool says otherwise.
- Default project: `C:/Users/63588/lenovo/ssg-sales-ops` (override with `--project`).
- Default timeout 90s; raise it (`--timeout 180`) for `WAIT_FOR_PAUSE` / long builds.
- PowerShell quoting: always single-quote ARGS_JSON and keep it on one line.
- Output is the unwrapped tool result as JSON; exit code 1 with `{"error": ...}` on failure.
- The wrapper opens one session per invocation; keep polling bounded.

## Recipes

```powershell
# which debug sessions exist (IDEA is often already debugging something)
python ...\idea_mcp.py xdebug_get_debugger_status {}

# break, run to it, inspect (prefer logpoints over suspending breakpoints)
python ...\idea_mcp.py xdebug_set_breakpoint '{"filePath":"smartop-service/admin/src/main/java/com/lenovo/admin/chat/controller/ChatController.java","line":30,"suspendPolicy":"NONE","logExpression":"chatMsg"}'
python ...\idea_mcp.py xdebug_control_session '{"action":"DRAIN_EVENTS"}'

# suspending debug round-trip
python ...\idea_mcp.py xdebug_set_breakpoint '{"filePath":"<rel-path>","line":123}'
python ...\idea_mcp.py xdebug_control_session '{"action":"RESUME"}'
python ...\idea_mcp.py xdebug_control_session '{"action":"WAIT_FOR_PAUSE","timeout":120000}' --timeout 150
python ...\idea_mcp.py xdebug_get_stack '{}'
python ...\idea_mcp.py xdebug_get_frame_values '{"depth":1}'

# build just the files you touched, then read real errors
python ...\idea_mcp.py build_project '{"filesToRebuild":["smartop-service/admin/src/main/java/com/lenovo/admin/chatbi/service/ChatbiTrackingService.java"]}'
python ...\idea_mcp.py get_build_output '{}'

# read what the running app printed
python ...\idea_mcp.py get_console_output '{}'
```

## Constraints

- Read-only first: snapshot / status / search before acting. IDEA must be running with the project open, or every call fails fast.
- One debug session at a time from this skill; pass `sessionId` explicitly when several exist.
- Mutating VCS / remote-state tools (`vcs_push`, `merge_*`, `update_*`, `create_pull_request`, …) need explicit user approval per call; never batch them silently.
- The wrapper prints tool errors as JSON — surface the message instead of retrying blindly. Stop after 3 consecutive failures of the same call and report back.
- Local-only: the endpoint (`127.0.0.1:64342`) and the wrapper never leave this machine; do not expose them or commit credentials alongside this skill.
