#!/usr/bin/env python3
"""Apply the exam word lists in Content/exams/ to Content/cards.json.

Each Content/exams/<exam>.json (exam is yds, yokdil or ielts) holds
  "words": [{"word", "pos", "level"}, ...]  the words the exam deck should have, and
  "cards": [{"word", "pos", "level", "tr", "example_en", "example_tr", "note"?}, ...]
           full cards for words that no course teaches.

A word a course already teaches gets the exam tag on that course card (same part of speech
first, then any). Other words become exam-only cards, id "exam-<word>", with only exam decks,
so they never reach a level course. Existing tags stay; exam-only cards are rebuilt each run.
Run it after tools/build_curriculum.py. Prints words that still need a card.

Usage: python3 tools/build_exams.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMS = ("yds", "yokdil", "ielts")
LEVEL_ORDER = ["A1", "A2", "B1", "B2", "C1", "C2"]


def main():
    path = ROOT / "Content" / "cards.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    before = json.dumps(data["cards"], sort_keys=True)
    data["cards"] = [c for c in data["cards"] if "general" in c["decks"]]
    by_word = {}
    for c in data["cards"]:
        if c["pos"] != "phrase":
            by_word.setdefault(c["word"].lower(), []).append(c)

    exam_only = {}
    missing = {}
    for exam in EXAMS:
        file = ROOT / "Content" / "exams" / f"{exam}.json"
        if not file.exists():
            continue
        spec = json.loads(file.read_text(encoding="utf-8"))
        defs = {d["word"].lower(): d for d in spec.get("cards", [])}
        tagged = added = 0
        for w in spec["words"]:
            word = w["word"].lower()
            matches = by_word.get(word, [])
            if matches:
                same = [c for c in matches if c["pos"] == w["pos"]] or matches
                card = max(same, key=lambda c: LEVEL_ORDER.index(c["level"]))
                if exam not in card["decks"]:
                    card["decks"].append(exam)
                tagged += 1
            elif word in defs:
                d = defs[word]
                card = exam_only.get(word)
                if card is None:
                    card = {"id": "exam-" + re.sub(r"[^a-z0-9]+", "-", word).strip("-"), "word": d["word"],
                            "pos": d["pos"], "level": d["level"], "tr": d["tr"],
                            "example_en": d["example_en"], "example_tr": d["example_tr"], "decks": []}
                    if d.get("note"):
                        card["note"] = d["note"]
                    exam_only[word] = card
                card["decks"].append(exam)
                added += 1
            else:
                missing.setdefault(exam, []).append(w)
        print(f"{exam}: {len(spec['words'])} words, {tagged} course cards tagged, {added} exam-only cards, "
              f"{len(missing.get(exam, []))} missing")

    for c in data["cards"]:
        c["decks"] = ["general"] + sorted(set(c["decks"]) - {"general"})
    data["cards"] += list(exam_only.values())
    if json.dumps(data["cards"], sort_keys=True) != before:
        data["contentVersion"] += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(exam_only)} exam-only cards -> {path.relative_to(ROOT)} (contentVersion {data['contentVersion']})")
    for exam, words in missing.items():
        print(f"missing {exam}: " + ", ".join(f"{w['word']} ({w['pos']}, {w['level']})" for w in words))


if __name__ == "__main__":
    main()
