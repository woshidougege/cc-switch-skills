"""Call the local IntelliJ IDEA MCP server (streamable HTTP JSON-RPC).

Usage:
    python idea_mcp.py TOOL_NAME [ARGS_JSON] [--project PATH] [--timeout SEC] [--raw]
    python idea_mcp.py --list [SUBSTRING]

Examples:
    python idea_mcp.py --list xdebug
    python idea_mcp.py xdebug_get_debugger_status {}
    python idea_mcp.py build_project {"filesToRebuild": ["smartop-service/admin/src/main/java/com/lenovo/admin/chatbi/service/ChatbiTrackingService.java"]}
    python idea_mcp.py xdebug_set_breakpoint {"filePath": "smartop-service/admin/src/main/java/com/lenovo/admin/chat/controller/ChatController.java", "line": 30}

The server speaks plain JSON-RPC over HTTP (no SSE). Each invocation opens
its own session (initialize -> tools/call), which is cheap on localhost.
Prints the unwrapped tool result as JSON (pretty). Exit code 1 on RPC/tool error.
"""
import argparse
import json
import sys
import urllib.request
import urllib.error

DEFAULT_URL = "http://127.0.0.1:64342/stream"
DEFAULT_PROJECT = "C:/Users/63588/lenovo/ssg-sales-ops"
_req_id = 0


def _next_id():
    global _req_id
    _req_id += 1
    return _req_id


def _post(url, project, payload, session=None, timeout=90):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "IJ_MCP_SERVER_PROJECT_PATH": project,
    }
    if session:
        headers["Mcp-Session-Id"] = session
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        body = resp.read().decode("utf-8")
        return json.loads(body), resp.headers.get("mcp-session-id")
    except urllib.error.HTTPError as e:
        raise RuntimeError("HTTP %s: %s" % (e.code, e.read().decode("utf-8")[:1000]))


def _session(url, project, timeout):
    data, sid = _post(url, project, {
        "jsonrpc": "2.0", "id": _next_id(), "method": "initialize",
        "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                   "clientInfo": {"name": "codex-idea-mcp-skill", "version": "1.0"}},
    }, timeout=timeout)
    if "error" in data:
        raise RuntimeError("initialize failed: %s" % json.dumps(data["error"]))
    return sid


def list_tools(url, project, timeout, filt=None):
    sid = _session(url, project, timeout)
    data, _ = _post(url, project, {
        "jsonrpc": "2.0", "id": _next_id(), "method": "tools/list", "params": {},
    }, session=sid, timeout=timeout)
    if "error" in data:
        raise RuntimeError("tools/list failed: %s" % json.dumps(data["error"]))
    tools = data["result"].get("tools", [])
    if filt:
        tools = [t for t in tools if filt.lower() in t["name"].lower()]
    return tools


def call_tool(url, project, name, args, timeout):
    sid = _session(url, project, timeout)
    data, _ = _post(url, project, {
        "jsonrpc": "2.0", "id": _next_id(), "method": "tools/call",
        "params": {"name": name, "arguments": args or {}},
    }, session=sid, timeout=timeout)
    if "error" in data:
        raise RuntimeError("tools/call RPC error: %s" % json.dumps(data["error"]))
    return data.get("result", {})


def unwrap(result):
    """Unwrap MCP content blocks; parse embedded JSON text when possible."""
    if not isinstance(result, dict) or "content" not in result:
        return result
    texts = [b.get("text", "") for b in result.get("content", [])
             if isinstance(b, dict) and b.get("type") == "text"]
    if result.get("isError"):
        raise RuntimeError("tool error: %s" % "\n".join(texts))
    if len(texts) == 1:
        try:
            return json.loads(texts[0])
        except (ValueError, TypeError):
            return texts[0]
    return result


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Call IntelliJ IDEA local MCP server")
    ap.add_argument("tool", nargs="?", help="MCP tool name to call")
    ap.add_argument("args", nargs="?", default="{}",
                    help="JSON object of tool arguments (default {})")
    ap.add_argument("--list", dest="list_filter", nargs="?", const="",
                    help="list tools, optionally filtered by substring")
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--project", default=DEFAULT_PROJECT)
    ap.add_argument("--timeout", type=int, default=90,
                    help="HTTP timeout seconds (raise for WAIT_FOR_PAUSE etc.)")
    ap.add_argument("--raw", action="store_true",
                    help="print raw RPC result without unwrapping")
    ns = ap.parse_args()
    try:
        if ns.list_filter is not None:
            tools = list_tools(ns.url, ns.project, ns.timeout,
                               ns.list_filter or None)
            out = [{"name": t["name"],
                    "description": (t.get("description") or "")[:200]}
                   for t in tools]
            print(json.dumps(out, ensure_ascii=False, indent=1))
            return 0
        if not ns.tool:
            ap.error("TOOL name required (or use --list)")
        try:
            args = json.loads(ns.args)
        except ValueError as e:
            raise RuntimeError("ARGS_JSON is not valid JSON: %s" % e)
        if not isinstance(args, dict):
            raise RuntimeError("ARGS_JSON must be a JSON object")
        result = call_tool(ns.url, ns.project, ns.tool, args, ns.timeout)
        if not ns.raw:
            try:
                result = unwrap(result)
            except RuntimeError as e:
                print(json.dumps({"error": str(e)}, ensure_ascii=False, indent=1))
                return 1
        print(json.dumps(result, ensure_ascii=False, indent=1, default=str))
        return 0
    except RuntimeError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False, indent=1))
        return 1


if __name__ == "__main__":
    sys.exit(main())