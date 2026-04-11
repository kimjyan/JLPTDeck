#!/usr/bin/env python3
"""Translate English glosses in jmdict_n4_n1.json to Korean using `claude -p`.

Idempotent: skips entries that already have a non-empty `gloss_ko`.
Resilient: writes after every batch so a Ctrl-C only loses ≤1 batch.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "JLPTDeck" / "Resources" / "jmdict_n4_n1.json"
BATCH_SIZE = 100
MODEL = "haiku"

PROMPT_HEADER = (
    "Translate these English Japanese-vocabulary glosses to natural Korean. "
    "For multi-sense entries pick the most common Japanese-learning meaning. "
    "Preserve verb form (use -다 for verbs). Keep nouns concise. "
    "Return JSON only, no prose, no code fences. "
    'Schema: {"items":[{"i":0,"ko":"..."},{"i":1,"ko":"..."}]}\n\n'
)


def translate_batch(batch_items):
    lines = [f"{i}: {gloss}" for i, gloss in batch_items]
    prompt = PROMPT_HEADER + "\n".join(lines)
    proc = subprocess.run(
        ["claude", "-p", "--model", MODEL, "--output-format", "json"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=180,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude exited {proc.returncode}: {proc.stderr[:500]}")
    result_envelope = json.loads(proc.stdout)
    if result_envelope.get("is_error"):
        raise RuntimeError(f"claude error: {result_envelope.get('result', '')[:500]}")
    raw = result_envelope["result"].strip()
    # Strip code fences if present
    if raw.startswith("```"):
        raw = raw.split("```", 2)[1]
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.strip()
        if raw.endswith("```"):
            raw = raw[:-3].strip()
    payload = json.loads(raw)
    return {item["i"]: item["ko"] for item in payload["items"]}


def main():
    entries = json.loads(BUNDLE.read_text(encoding="utf-8"))
    total = len(entries)
    todo_indices = [
        idx for idx, e in enumerate(entries)
        if not e.get("gloss_ko", "").strip()
    ]
    print(f"total={total} translated={total - len(todo_indices)} todo={len(todo_indices)}", flush=True)

    for start in range(0, len(todo_indices), BATCH_SIZE):
        chunk = todo_indices[start:start + BATCH_SIZE]
        batch_items = [(local_i, entries[global_i]["gloss"]) for local_i, global_i in enumerate(chunk)]
        try:
            mapping = translate_batch(batch_items)
        except Exception as exc:
            print(f"batch {start}-{start+len(chunk)} FAILED: {exc}", flush=True)
            continue
        for local_i, global_i in enumerate(chunk):
            ko = mapping.get(local_i, "").strip()
            if ko:
                entries[global_i]["gloss_ko"] = ko
        BUNDLE.write_text(
            json.dumps(entries, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        done = sum(1 for e in entries if e.get("gloss_ko", "").strip())
        print(f"batch {start//BATCH_SIZE + 1}: wrote up to {chunk[-1]+1}/{total} | total ko={done}", flush=True)

    final = sum(1 for e in entries if e.get("gloss_ko", "").strip())
    print(f"DONE. {final}/{total} entries have gloss_ko", flush=True)


if __name__ == "__main__":
    main()
