#!/usr/bin/env python3
"""Have Gemini check every card in Content/cards.json, one by one, and write a report.

Claude drafts the cards; Gemini reviews them independently as an English-Turkish
lexicographer. Two different models rarely make the same mistake, so their disagreements
are where a human should look.

For each card Gemini answers:
  - are the Turkish meanings right for this part of speech, and is a common one missing?
    (e.g. challenge: "zorluk" alone misses "meydan okuma")
  - does example_en use the word in that sense, naturally, at that level?
  - is example_tr a correct, natural translation?
  - is the CEFR level plausible?
and proposes corrected fields when something is wrong.

Output (in Content/review/):
  <name>.review.json  one result per card, resumable: cards already reviewed are skipped
  <name>.review.md    the cards Gemini flagged, for a human to read

API key: create a free key at https://aistudio.google.com/apikey and put it in a file
named .env.local in the repo root (git ignores it):
    GEMINI_API_KEY=...
The key is only sent to Google's API. A Gemini app subscription (Gemini Pro) does not
include API access; the AI Studio key is separate and has its own free tier.

Usage:
  python3 tools/gemini_review.py                       # reviews Content/cards.json
  python3 tools/gemini_review.py path/to/cards.json --batch 15 --model gemini-2.5-pro
  python3 tools/gemini_review.py --list-models         # models this key can use
Runs on Python 3.9+, standard library only.
"""
import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = "https://generativelanguage.googleapis.com/v1beta"
DEFAULT_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-pro")
MAX_TR, MAX_SENTENCE = 28, 55

SYSTEM = f"""You are a senior English-Turkish lexicographer and an experienced teacher of English
to Turkish speakers. You review flashcards for a vocabulary app shown on the iPhone lock screen.
Be strict and precise. Native Turkish usage matters: translations must sound like a careful
Turkish teacher wrote them, not like machine translation.

For each card, check:
1. meanings: Are the Turkish meanings (tr) correct for the given part of speech (pos)?
   Is the most common meaning first? Is an important common meaning of that pos missing?
   Example of a problem: "challenge" (n) with only "zorluk" misses "meydan okuma".
   Other parts of speech of the same word are NOT missing meanings; list them separately
   in other_senses.
2. example_en: Does it use the word in the card's sense and pos? Is it natural, correct
   English suited to the CEFR level? Must be at most {MAX_SENTENCE} characters.
3. example_tr: Is it a correct, natural Turkish translation of example_en?
   Must be at most {MAX_SENTENCE} characters.
4. level: Is the CEFR level plausible for this word in this sense?
5. Limits: the Turkish meanings joined with ", " must be at most {MAX_TR} characters.

verdict: "ok" when the card is correct as is (minor style preferences are not errors),
"fix" when something is wrong and your corrected fields solve it, "unsure" when you are
not confident either way. Put corrected values only in the fix_* fields you change;
leave the others empty. Write issues in Turkish, short."""

ITEM_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "id": {"type": "STRING"},
        "verdict": {"type": "STRING", "enum": ["ok", "fix", "unsure"]},
        "issues": {"type": "ARRAY", "items": {"type": "STRING"}},
        "fix_tr": {"type": "ARRAY", "items": {"type": "STRING"}},
        "fix_example_en": {"type": "STRING"},
        "fix_example_tr": {"type": "STRING"},
        "fix_level": {"type": "STRING", "enum": ["", "A1", "A2", "B1", "B2", "C1", "C2"]},
        "other_senses": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "pos": {"type": "STRING"},
                    "tr": {"type": "ARRAY", "items": {"type": "STRING"}},
                    "example_en": {"type": "STRING"},
                    "example_tr": {"type": "STRING"},
                },
                "required": ["pos", "tr", "example_en", "example_tr"],
            },
        },
        "confidence": {"type": "STRING", "enum": ["high", "medium", "low"]},
    },
    "required": ["id", "verdict", "issues", "confidence"],
}
RESPONSE_SCHEMA = {"type": "ARRAY", "items": ITEM_SCHEMA}


def load_key():
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    env = ROOT / ".env.local"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            name, _, value = line.partition("=")
            if name.strip() in ("GEMINI_API_KEY", "GOOGLE_API_KEY") and value.strip():
                key = value.strip().strip('"').strip("'")
    if not key:
        sys.exit("No API key. Put GEMINI_API_KEY=... in .env.local (see the top of this file).")
    return key


def request(url, key, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method="POST" if data else "GET",
                                 headers={"x-goog-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as response:
        return json.loads(response.read())


def list_models(key):
    result = request(f"{API}/models?pageSize=200", key)
    for m in result.get("models", []):
        if "generateContent" in m.get("supportedGenerationMethods", []):
            print(m["name"].removeprefix("models/"), "-", m.get("displayName", ""))


def card_hash(card):
    """Changes when the card's content changes, so edited cards are reviewed again."""
    fields = {k: card[k] for k in ("word", "pos", "level", "tr", "example_en", "example_tr")}
    return hashlib.sha256(json.dumps(fields, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]


def review_batch(cards, key, model):
    payload = [{k: c[k] for k in ("id", "word", "pos", "level", "tr", "example_en", "example_tr")} for c in cards]
    body = {
        "systemInstruction": {"parts": [{"text": SYSTEM}]},
        "contents": [{"role": "user", "parts": [{"text":
            "Review these cards. Return one result per card, same ids, same order.\n"
            + json.dumps(payload, ensure_ascii=False, indent=1)}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "responseSchema": RESPONSE_SCHEMA,
        },
    }
    delay = 20
    for attempt in range(8):
        try:
            result = request(f"{API}/models/{model}:generateContent", key, body)
            text = result["candidates"][0]["content"]["parts"][0]["text"]
            items = json.loads(text)
            by_id = {item["id"]: item for item in items}
            missing = [c["id"] for c in cards if c["id"] not in by_id]
            if missing:
                raise ValueError(f"missing results for {missing}")
            return by_id
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:300]
            if e.code in (429, 500, 503):
                print(f"  HTTP {e.code}, waiting {delay}s ({detail[:80]})", flush=True)
                time.sleep(delay)
                delay = min(delay * 2, 300)
                continue
            sys.exit(f"HTTP {e.code}: {detail}")
        except (KeyError, IndexError, ValueError, json.JSONDecodeError) as e:
            print(f"  bad response ({e}), retrying", flush=True)
            time.sleep(5)
    sys.exit("Gave up after repeated errors; rerun to resume.")


def write_report(cards, results, path):
    flagged = [c for c in cards if results.get(c["id"], {}).get("verdict") in ("fix", "unsure")]
    counts = {v: sum(1 for r in results.values() if r.get("verdict") == v) for v in ("ok", "fix", "unsure")}
    lines = [f"# Gemini review: {len(results)} cards", "",
             f"ok {counts['ok']} · fix {counts['fix']} · unsure {counts['unsure']}", ""]
    for c in flagged:
        r = results[c["id"]]
        lines.append(f"## {c['word']} ({c['pos']}, {c['level']}) · {r['verdict']} · {r.get('confidence', '')}")
        lines.append(f"- now: {', '.join(c['tr'])} — _{c['example_en']}_ / {c['example_tr']}")
        for issue in r.get("issues", []):
            lines.append(f"- {issue}")
        fixes = {k: r[k] for k in ("fix_tr", "fix_example_en", "fix_example_tr", "fix_level") if r.get(k)}
        if fixes:
            lines.append(f"- öneri: `{json.dumps(fixes, ensure_ascii=False)}`")
        for s in r.get("other_senses", []):
            lines.append(f"- diğer anlam ({s['pos']}): {', '.join(s['tr'])} — _{s['example_en']}_ / {s['example_tr']}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cards", nargs="?", default=str(ROOT / "Content" / "cards.json"))
    parser.add_argument("--batch", type=int, default=15)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--limit", type=int, default=0, help="review at most N cards (for a pilot)")
    parser.add_argument("--list-models", action="store_true")
    args = parser.parse_args()

    key = load_key()
    if args.list_models:
        return list_models(key)

    src = Path(args.cards)
    cards = json.loads(src.read_text(encoding="utf-8"))["cards"]
    if args.limit:
        cards = cards[: args.limit]
    out_dir = ROOT / "Content" / "review"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{src.stem}.review.json"
    saved = json.loads(out.read_text(encoding="utf-8")) if out.exists() else {}

    todo = [c for c in cards if saved.get(c["id"], {}).get("_hash") != card_hash(c)]
    print(f"{len(cards)} cards, {len(cards) - len(todo)} already reviewed, {len(todo)} to go, model {args.model}")
    for i in range(0, len(todo), args.batch):
        batch = todo[i: i + args.batch]
        results = review_batch(batch, key, args.model)
        for c in batch:
            saved[c["id"]] = {**results[c["id"]], "_hash": card_hash(c), "_model": args.model}
        out.write_text(json.dumps(saved, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"  {min(i + args.batch, len(todo))}/{len(todo)}", flush=True)

    counts = write_report(cards, saved, out_dir / f"{src.stem}.review.md")
    print(f"done: ok {counts['ok']}, fix {counts['fix']}, unsure {counts['unsure']} -> {out_dir.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
