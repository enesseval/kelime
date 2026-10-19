#!/usr/bin/env python3
"""Merge the course in Content/curriculum/<LEVEL>/ into Content/cards.json.

Each unit's words become cards (main sense in the card's fields, further senses in
"senses"), its phrases become cards with pos "phrase", and the unit itself goes into
"units" with its card ids in order and its stories. A card shared by two units (table,
pay) is written once. Cards and units of the level are replaced; other levels are kept.
contentVersion goes up by one, so installed apps import the change.

Run tools/check_unit.py first; this script assumes the units are valid.
Usage: python3 tools/build_curriculum.py A1
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def card_from_word(w, level):
    main, *rest = w["senses"]
    card = {"id": w["id"], "word": w["word"], "pos": main["pos"], "level": level, "tr": main["tr"],
            "example_en": main["example_en"], "example_tr": main["example_tr"], "decks": ["general"]}
    if w.get("note"):
        card["note"] = w["note"]
    if rest:
        card["senses"] = rest
    return card


def card_from_phrase(p, level):
    card = {"id": p["id"], "word": p["text"], "pos": "phrase", "level": level, "tr": [p["tr"]],
            "example_en": p["example_en"], "example_tr": p["example_tr"], "decks": ["general"]}
    if p.get("note"):
        card["note"] = p["note"]
    return card


def main():
    level = sys.argv[1]
    folder = ROOT / "Content" / "curriculum" / level
    plan = json.loads((folder / "plan.json").read_text(encoding="utf-8"))
    files = {f.stem: json.loads(f.read_text(encoding="utf-8")) for f in folder.glob("*.json") if f.stem != "plan"}
    by_id = {u["id"]: u for u in files.values()}
    # Core first, then the any-order units (plan order, then the rest), then the bridge.
    planned = [u["id"] for u in plan["units"]]
    rank = {"first": 0, "any": 1, "last": 2}
    order = sorted(by_id, key=lambda uid: (rank[by_id[uid]["placement"]],
                                           planned.index(uid) if uid in planned else len(planned), uid))

    cards, units = {}, []
    for position, uid in enumerate(order):
        unit = by_id[uid]
        ids = []
        for w in unit["words"]:
            cards.setdefault(w["id"], card_from_word(w, level))
            ids.append(w["id"])
        for p in unit["phrases"]:
            cards.setdefault(p["id"], card_from_phrase(p, level))
            ids.append(p["id"])
        units.append({"id": uid, "level": level, "title": unit["title"], "goal": unit["goal"],
                      "placement": unit["placement"], "position": position,
                      "stories": [{"id": s["id"], "title": s["title"], "lines": s["lines"]} for s in unit["stories"]],
                      "cards": ids})

    path = ROOT / "Content" / "cards.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data["cards"] = [c for c in data["cards"] if c["level"] != level] + list(cards.values())
    data["units"] = [u for u in data.get("units", []) if u["level"] != level] + units
    data["contentVersion"] += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{level}: {len(cards)} cards in {len(units)} units -> {path.relative_to(ROOT)} "
          f"(contentVersion {data['contentVersion']})")


if __name__ == "__main__":
    main()
