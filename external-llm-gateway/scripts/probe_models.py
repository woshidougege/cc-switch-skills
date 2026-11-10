#!/usr/bin/env python3
"""List gateway models and optionally probe their modality support.

Usage:
  python probe_models.py                    # just list models
  python probe_models.py --probe-image x.jpg
  python probe_models.py --probe-video v.mp4 --models minimax-m3,space-bunny
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


def get_json(cfg, path):
    req = urllib.request.Request(cfg["base_url"] + path, method="GET")
    req.add_header("Authorization", "Bearer " + cfg["api_key"])
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def post_json(cfg, path, body, timeout=300):
    raw = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(cfg["base_url"] + path, data=raw, method="POST")
    req.add_header("Authorization", "Bearer " + cfg["api_key"])
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def b64_of(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def norm_models(raw):
    data = raw.get("data", raw if isinstance(raw, list) else [])
    out = []
    for m in data:
        out.append({
            "id": m.get("id"),
            "modalities": m.get("input_modalities") or m.get("input") or m.get("capabilities") or "?",
            "context": m.get("context_window") or m.get("context") or "?",
            "max_tokens": m.get("max_tokens") or m.get("max_output_tokens") or "?",
        })
    return out


DENY = ["can not", "cannot", "unable to view", "unable to see", "not able to",
        "do not have the ability", "text-based", "text-only", "not support",
        "does not support", "has been filtered", "filtered out",
        "only process text and images", "dont see", "no video", "not multimodal"]


def looks_like_deny(text):
    t = (text or "").lower()
    for a, b in ((chr(8217), chr(39)), (chr(8216), chr(39)), (chr(8220), chr(34)), (chr(8221), chr(34))):
        t = t.replace(a, b)
    return any(k in t for k in DENY)


def probe(cfg, model, content, tag):
    try:
        resp = post_json(cfg, "/chat/completions", {
            "model": model,
            "messages": [{"role": "user", "content": content}],
            "max_tokens": 3000,
        })
        msg = resp.get("choices", [{}])[0].get("message", {})
        text = msg.get("content") or ""
        usage = resp.get("usage", {})
        verdict = "SAW-IT" if (text.strip() and not looks_like_deny(text)) else "SEES-NOTHING"
        print("[" + tag + "] " + model + " -> " + verdict)
        print("    " + text.replace(chr(10), " ")[:220])
        print("    usage=" + json.dumps(usage, ensure_ascii=False))
    except urllib.error.HTTPError as e:
        print("[" + tag + "] " + model + " -> HTTP " + str(e.code) + " " + e.read().decode("utf-8", "replace")[:160])
    except Exception as e:
        print("[" + tag + "] " + model + " -> ERR " + repr(e)[:160])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--models", default=None, help="comma separated model ids; default = all")
    p.add_argument("--probe-image", default=None)
    p.add_argument("--probe-video", default=None)
    p.add_argument("--probe-audio", default=None)
    p.add_argument("--list-only", action="store_true")
    args = p.parse_args()

    cfg = load_cfg()
    raw = get_json(cfg, "/models")
    models = norm_models(raw)
    print("=== " + str(len(models)) + " models ===")
    for m in models:
        print("  " + str(m["id"]) + "  modalities=" + str(m["modalities"])
              + "  ctx=" + str(m["context"]) + "  maxOut=" + str(m["max_tokens"]))
    if args.list_only or not (args.probe_image or args.probe_video or args.probe_audio):
        return 0

    ids = [x.strip() for x in args.models.split(",")] if args.models else [m["id"] for m in models]
    if args.probe_image:
        img = "data:image/jpeg;base64," + b64_of(args.probe_image)
        for mid in ids:
            probe(cfg, mid, [{"type": "text", "text": "describe this image briefly"},
                             {"type": "image_url", "image_url": {"url": img}}], "image")
    if args.probe_video:
        vid = "data:video/mp4;base64," + b64_of(args.probe_video)
        for mid in ids:
            probe(cfg, mid, [{"type": "text", "text": "describe what is shown in this video"},
                             {"type": "video_url", "video_url": {"url": vid}, "fps": 2,
                              "media_resolution": "default"}], "video")
    if args.probe_audio:
        aud = "data:audio/wav;base64," + b64_of(args.probe_audio)
        for mid in ids:
            probe(cfg, mid, [{"type": "text", "text": "transcribe this audio"},
                             {"type": "input_audio", "input_audio": {"data": aud}}], "audio")
    return 0


if __name__ == "__main__":
    sys.exit(main())
