#!/usr/bin/env python3
"""Validate Content/cards.json.

Checks the schema, the length limits (word <= 16, joined Turkish meaning <= 28,
sentences <= 55 characters), that the word appears in example_en, unique ids,
and that every card has a level and at least one deck.

Course cards (A1, built from Content/curriculum by tools/build_curriculum.py) may be
phrases (pos "phrase", up to 28 characters), capitalised (Monday), have up to 3 meanings,
a note and extra senses. Course units must list existing card ids.

Usage: python3 tools/validate_cards.py [path/to/cards.json]
Runs on any OS with Python 3.9+. Exits with status 1 on any error.
"""
import json
import re
import sys
from pathlib import Path

LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2"}
POS = {"adj", "n", "v", "adv", "prep", "conj", "phrase"}
DECKS = {"general", "yds", "yokdil", "ielts"}
FIELDS = {"id", "word", "pos", "level", "tr", "example_en", "example_tr", "decks"}
OPTIONAL = {"note", "senses"}
COURSE_LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2"}
MAX_WORD, MAX_TR, MAX_SENTENCE = 16, 28, 55


def validate(data):
    errors = []
    if not isinstance(data.get("contentVersion"), int):
        errors.append("top level: contentVersion must be an integer")
    cards = data.get("cards")
    if not isinstance(cards, list) or not cards:
        return errors + ["top level: cards must be a non-empty list"]

    seen = set()
    for i, card in enumerate(cards):
        where = f"card {i} ({card.get('id', '?')})"
        missing = FIELDS - card.keys()
        extra = card.keys() - FIELDS - OPTIONAL
        if missing:
            errors.append(f"{where}: missing {sorted(missing)}")
            continue
        if extra:
            errors.append(f"{where}: unknown fields {sorted(extra)}")

        cid, word = card["id"], card["word"]
        course = card["level"] in COURSE_LEVELS
        phrase = card["pos"] == "phrase"
        if cid in seen:
            errors.append(f"{where}: duplicate id")
        seen.add(cid)
        if card["level"] not in LEVELS:
            errors.append(f"{where}: bad level {card['level']!r}")
        elif not course and cid != f"{card['level'].lower()}-{word}":
            errors.append(f"{where}: id should be {card['level'].lower()}-{word}")
        if card["pos"] not in POS:
            errors.append(f"{where}: bad pos {card['pos']!r}")
        if phrase:
            if not course:
                errors.append(f"{where}: phrases belong to the course levels")
            if len(word) > MAX_TR:
                errors.append(f"{where}: phrase longer than {MAX_TR}")
        else:
            if not re.fullmatch(r"[^\W\d_]+(?:-[^\W\d_]+)*" if course else r"[a-z]+", word):
                errors.append(f"{where}: word must be ASCII letters only")
            if len(word) > MAX_WORD:
                errors.append(f"{where}: word longer than {MAX_WORD}")

        tr = card["tr"]
        most = 3 if course else 2
        if not isinstance(tr, list) or not 1 <= len(tr) <= most or not all(isinstance(t, str) and t.strip() for t in tr):
            errors.append(f"{where}: tr must hold 1-{most} non-empty strings")
        elif len(", ".join(tr)) > MAX_TR:
            errors.append(f"{where}: Turkish meaning longer than {MAX_TR}: {', '.join(tr)!r}")

        for key in ("example_en", "example_tr"):
            text = card[key]
            if not isinstance(text, str) or not text.strip():
                errors.append(f"{where}: {key} is empty")
            elif len(text) > MAX_SENTENCE:
                errors.append(f"{where}: {key} longer than {MAX_SENTENCE} ({len(text)})")
        if not phrase and isinstance(card["example_en"], str) and word.lower() not in card["example_en"].lower():
            errors.append(f"{where}: word does not appear in example_en")
        for sense in card.get("senses") or []:
            if sense.get("pos") not in POS or not sense.get("tr") or len(", ".join(sense["tr"])) > MAX_TR:
                errors.append(f"{where}: bad extra sense {sense}")
            for key in ("example_en", "example_tr"):
                if not sense.get(key) or len(sense[key]) > MAX_SENTENCE:
                    errors.append(f"{where}: extra sense {key} empty or too long")

        decks = card["decks"]
        if not isinstance(decks, list) or not decks:
            errors.append(f"{where}: decks must be a non-empty list")
        elif set(decks) - DECKS:
            errors.append(f"{where}: unknown decks {sorted(set(decks) - DECKS)}")

    unit_ids = set()
    for unit in data.get("units") or []:
        if unit["id"] in unit_ids:
            errors.append(f"unit {unit['id']}: duplicate id")
        unit_ids.add(unit["id"])
        for cid in unit["cards"]:
            if cid not in seen:
                errors.append(f"unit {unit['id']}: unknown card {cid}")
        if unit.get("placement") not in ("first", "any", "last"):
            errors.append(f"unit {unit['id']}: bad placement")
        if not unit.get("stories"):
            errors.append(f"unit {unit['id']}: no stories")
    return errors


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "Content" / "cards.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    errors = validate(data)
    for e in errors:
        print(f"ERROR {e}")
    cards = data.get("cards") or []
    by_level = {}
    for c in cards:
        by_level[c.get("level")] = by_level.get(c.get("level"), 0) + 1
    summary = ", ".join(f"{k}: {v}" for k, v in sorted(by_level.items(), key=lambda kv: str(kv[0])))
    print(f"{len(cards)} cards ({summary}), {len(errors)} error(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
