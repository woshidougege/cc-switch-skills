#!/usr/bin/env python3
"""Generic caller for the local WorkBuddy2API gateway (OpenAI compatible).

Usage:
  python llm_call.py --model deepseek-v4.1-flash --prompt "hello"
  python llm_call.py --model mimo-v2.6-pro --image shot.jpg --prompt "describe this UI"
  python llm_call.py --model minimax-m3 --video clip.mp4 --prompt "describe the screen" --max-tokens 3000
  python llm_call.py --model deepseek-v4.1-flash --prompt-file q.txt --json

Read config.json next to this file for base_url + api_key.
"""
import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(HERE, "config.json")


def load_cfg():
    with open(CFG, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    cfg["base_url"] = os.environ.get("WB_GATEWAY_URL", cfg.get("base_url", "http://127.0.0.1:8788/v1"))
    cfg["api_key"] = os.environ.get("WORK_BUDDY_API_KEY", cfg.get("api_key", ""))
    return cfg


def b64_of(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def guess_mime(path, fallback):
    ext = os.path.splitext(path)[1].lower()
    table = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
             ".webp": "image/webp", ".gif": "image/gif",
             ".mp4": "video/mp4", ".mov": "video/quicktime", ".webm": "video/webm",
             ".wav": "audio/wav", ".mp3": "audio/mpeg", ".m4a": "audio/mp4"}
    return table.get(ext, fallback)


def build_content(args):
    parts = []
    if args.prompt:
        parts.append({"type": "text", "text": args.prompt})
    if args.image:
        mime = guess_mime(args.image, "image/jpeg")
        parts.append({"type": "image_url",
                      "image_url": {"url": "data:" + mime + ";base64," + b64_of(args.image)}})
    if args.video:
        mime = guess_mime(args.video, "video/mp4")
        parts.append({"type": "video_url",
                      "video_url": {"url": "data:" + mime + ";base64," + b64_of(args.video)},
                      "fps": args.fps,
                      "media_resolution": args.media_resolution})
    if args.audio:
        mime = guess_mime(args.audio, "audio/wav")
        parts.append({"type": "input_audio",
                      "input_audio": {"data": "data:" + mime + ";base64," + b64_of(args.audio)}})
    return parts


def call(cfg, model, content, max_tokens, temperature, timeout):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "max_tokens": max_tokens,
    }
    if temperature is not None:
        body["temperature"] = temperature
    raw = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(cfg["base_url"] + "/chat/completions", data=raw, method="POST")
    req.add_header("Authorization", "Bearer " + cfg["api_key"])
    req.add_header("api-key", cfg["api_key"])
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def main():
    p = argparse.ArgumentParser(description="Call the local WorkBuddy2API gateway")
    p.add_argument("--model", required=True, help="model id, e.g. minimax-m3")
    p.add_argument("--prompt", default=None, help="text prompt")
    p.add_argument("--prompt-file", default=None, help="read prompt from a text file")
    p.add_argument("--image", default=None, help="image file to attach")
    p.add_argument("--video", default=None, help="video file to attach (only a few models can see it)")
    p.add_argument("--audio", default=None, help="audio file (gateway currently rejects input_audio)")
    p.add_argument("--fps", type=float, default=2.0, help="video sampling fps")
    p.add_argument("--media-resolution", default="default", help="video media_resolution")
    p.add_argument("--max-tokens", type=int, default=1024)
    p.add_argument("--temperature", type=float, default=None)
    p.add_argument("--timeout", type=int, default=600, help="seconds")
    p.add_argument("--json", action="store_true", help="print the raw response JSON")
    args = p.parse_args()

    if args.prompt_file:
        with open(args.prompt_file, "r", encoding="utf-8") as f:
            args.prompt = f.read()
    if not args.prompt and not (args.image or args.video or args.audio):
        p.error("need --prompt or at least one of --image/--video/--audio")

    content = build_content(args)
    cfg = load_cfg()
    try:
        resp = call(cfg, args.model, content, args.max_tokens, args.temperature, args.timeout)
    except urllib.error.HTTPError as e:
        sys.stderr.write("HTTP " + str(e.code) + ": " + e.read().decode("utf-8", "replace") + os.linesep)
        return 2
    except Exception as e:
        sys.stderr.write("ERROR: " + repr(e) + os.linesep)
        return 3

    if args.json:
        print(json.dumps(resp, ensure_ascii=False, indent=2))
        return 0

    try:
        msg = resp["choices"][0]["message"]
        text = msg.get("content") or ""
        reasoning = msg.get("reasoning_content") or ""
        usage = resp.get("usage", {})
        if reasoning:
            print("--- reasoning (" + str(len(reasoning)) + " chars) ---")
            print(reasoning[:2000])
        print("--- content ---")
        print(text)
        print("--- meta ---")
        print("model=" + str(resp.get("model")))
        print("finish=" + str(resp["choices"][0].get("finish_reason")))
        print("usage=" + json.dumps(usage, ensure_ascii=False))
    except Exception:
        print(json.dumps(resp, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())