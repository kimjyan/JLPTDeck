#!/usr/bin/env python3
"""Translate English glosses in jmdict_n4_n1.json to Korean using `claude -p`.

Idempotent: skips entries that already have a non-empty `gloss_ko`.
Parallel: spawns N worker subprocesses, each handling a slice of the todo list.
Resilient: each worker writes its slice to disk after every batch.
"""
import concurrent.futures
import json
import os
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "JLPTDeck" / "Resources" / "jmdict_n4_n1.json"
BATCH_SIZE = 500
PARALLEL = 4
MODEL = "haiku"

PROMPT_HEADER = (
    "Translate these English Japanese-vocabulary glosses to natural Korean. "
    "For multi-sense entries pick the most common Japanese-learning meaning. "
    "Preserve verb form (use -다 for verbs). Keep nouns concise. "
    "Return JSON only, no prose, no code fences. "
    'Schema: {"items":[{"i":0,"ko":"..."},...]}\n\n'
)

write_lock = threading.Lock()
entries_global = None  # populated in main, mutated by workers under lock


def translate_batch(batch_items):
    lines = [f"{i}: {gloss}" for i, gloss in batch_items]
    prompt = PROMPT_HEADER + "\n".join(lines)
    proc = subprocess.run(
        ["claude", "-p", "--model", MODEL, "--output-format", "json"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude exit {proc.returncode}: {proc.stderr[:300]}")
    env = json.loads(proc.stdout)
    if env.get("is_error"):
        raise RuntimeError(f"claude err: {env.get('result', '')[:300]}")
    raw = env["result"].strip()
    if raw.startswith("```"):
        raw = raw.split("```", 2)[1]
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.strip()
        if raw.endswith("```"):
            raw = raw[:-3].strip()
    payload = json.loads(raw)
    return {item["i"]: item["ko"] for item in payload["items"]}


def worker(worker_id, slice_indices):
    """Process one slice of global indices in BATCH_SIZE chunks."""
    for start in range(0, len(slice_indices), BATCH_SIZE):
        chunk = slice_indices[start:start + BATCH_SIZE]
        batch_items = [(local_i, entries_global[g]["gloss"]) for local_i, g in enumerate(chunk)]
        try:
            mapping = translate_batch(batch_items)
        except Exception as exc:
            print(f"[w{worker_id}] batch {start}-{start+len(chunk)} FAILED: {exc}", flush=True)
            continue
        with write_lock:
            for local_i, g in enumerate(chunk):
                ko = mapping.get(local_i, "").strip()
                if ko:
                    entries_global[g]["gloss_ko"] = ko
            BUNDLE.write_text(
                json.dumps(entries_global, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
            done = sum(1 for e in entries_global if e.get("gloss_ko", "").strip())
            print(f"[w{worker_id}] +{len(chunk)} | total ko={done}/{len(entries_global)}", flush=True)


def main():
    global entries_global
    entries_global = json.loads(BUNDLE.read_text(encoding="utf-8"))
    total = len(entries_global)
    todo = [i for i, e in enumerate(entries_global) if not e.get("gloss_ko", "").strip()]
    print(f"total={total} done={total - len(todo)} todo={len(todo)} batch={BATCH_SIZE} workers={PARALLEL}", flush=True)

    if not todo:
        print("nothing to do", flush=True)
        return

    # Round-robin slice todo across workers so each worker has roughly equal load
    slices = [[] for _ in range(PARALLEL)]
    for i, g in enumerate(todo):
        slices[i % PARALLEL].append(g)

    with concurrent.futures.ThreadPoolExecutor(max_workers=PARALLEL) as ex:
        futures = [ex.submit(worker, wid, slc) for wid, slc in enumerate(slices)]
        for f in concurrent.futures.as_completed(futures):
            try:
                f.result()
            except Exception as exc:
                print(f"worker failed: {exc}", flush=True)

    final = sum(1 for e in entries_global if e.get("gloss_ko", "").strip())
    print(f"DONE. {final}/{total}", flush=True)


if __name__ == "__main__":
    main()
