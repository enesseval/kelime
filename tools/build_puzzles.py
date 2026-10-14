#!/usr/bin/env python3
"""Generate the bundled daily crosswords from Content/cards.json.

For every level with cards in the general deck, writes Content/puzzles/<LEVEL>.json with
--count puzzles (default 400) built from that level's words, using a fixed seed so the output
is reproducible. Every puzzle is validated before it is written; the Swift test suite
validates the files again.

Rules (same as the on-device generator in KelimeCore/CrosswordGenerator.swift):
- free-form layout within 10 x 10, at least 6 words, aiming for 7
- words cross only on matching letters
- no letter cells touch unless they cross; the cells right before and after a word are empty

Usage: python3 tools/build_puzzles.py [--count 400] [--seed 20261013]
Runs on any OS with Python 3.9+.
"""
import argparse
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE, MIN_WORDS, TARGET_WORDS, ATTEMPTS = 10, 6, 7, 40


class Board:
    def __init__(self):
        self.cells = {}  # (r, c) -> letter
        self.owners = {}  # (r, c) -> set of directions
        self.placed = []  # (answer, card_id, r, c, dir)

    def place(self, answer, card_id, r, c, d):
        dr, dc = (0, 1) if d == "a" else (1, 0)
        for i, ch in enumerate(answer):
            p = (r + dr * i, c + dc * i)
            self.cells[p] = ch
            self.owners.setdefault(p, set()).add(d)
        self.placed.append((answer, card_id, r, c, d))

    def check(self, answer, r, c, d):
        dr, dc = (0, 1) if d == "a" else (1, 0)
        end = (r + dr * (len(answer) - 1), c + dc * (len(answer) - 1))
        if r < 0 or c < 0 or end[0] >= SIZE or end[1] >= SIZE:
            return None
        if (r - dr, c - dc) in self.cells or (end[0] + dr, end[1] + dc) in self.cells:
            return None
        crossings = 0
        for i, ch in enumerate(answer):
            p = (r + dr * i, c + dc * i)
            if p in self.cells:
                if self.cells[p] != ch or d in self.owners[p]:
                    return None
                crossings += 1
            elif (p[0] - dc, p[1] - dr) in self.cells or (p[0] + dc, p[1] + dr) in self.cells:
                return None
        return crossings if 0 < crossings < len(answer) else None

    def best_placement(self, answer, rng):
        options = []
        for (r, c), existing in sorted(self.cells.items()):
            for i, ch in enumerate(answer):
                if ch != existing:
                    continue
                n = self.check(answer, r, c - i, "a")
                if n:
                    options.append((n, r, c - i, "a"))
                n = self.check(answer, r - i, c, "d")
                if n:
                    options.append((n, r - i, c, "d"))
        if not options:
            return None
        most = max(o[0] for o in options)
        return rng.choice([o for o in options if o[0] == most])

    def to_puzzle(self, pid):
        rows = [p[0] for p in self.cells]
        cols = [p[1] for p in self.cells]
        min_r, min_c = min(rows), min(cols)
        starts = sorted({(r - min_r, c - min_c) for _, _, r, c, _ in self.placed})
        number = {s: i + 1 for i, s in enumerate(starts)}
        entries = []
        for answer, card_id, r, c, d in self.placed:
            s = (r - min_r, c - min_c)
            entries.append({"n": number[s], "dir": d, "r": s[0], "c": s[1], "answer": answer, "card_id": card_id})
        return {"id": pid, "width": max(cols) - min_c + 1, "height": max(rows) - min_r + 1, "entries": entries}


def attempt(words, rng, pid):
    pool = words[:]
    rng.shuffle(pool)
    board = Board()
    first = pool[0]
    board.place(first[0], first[1], rng.randint(3, 6), rng.randint(0, SIZE - len(first[0])), "a")
    used = {first[0]}
    for answer, card_id in pool[1:]:
        if len(board.placed) >= TARGET_WORDS:
            break
        if answer in used:
            continue
        spot = board.best_placement(answer, rng)
        if spot:
            _, r, c, d = spot
            board.place(answer, card_id, r, c, d)
            used.add(answer)
    return board.to_puzzle(pid) if len(board.placed) >= MIN_WORDS else None


def validate(p):
    """Returns a list of problems (empty when valid)."""
    problems, letters, owners = [], {}, {}
    for e in p["entries"]:
        dr, dc = (0, 1) if e["dir"] == "a" else (1, 0)
        if not e["answer"].isascii() or not e["answer"].isalpha() or not e["answer"].isupper():
            problems.append(f"{e['n']}{e['dir']} not A-Z")
        for i, ch in enumerate(e["answer"]):
            cell = (e["r"] + dr * i, e["c"] + dc * i)
            if not (0 <= cell[0] < p["height"] and 0 <= cell[1] < p["width"]):
                problems.append(f"{e['n']}{e['dir']} out of bounds")
            if letters.get(cell, ch) != ch:
                problems.append(f"conflict at {cell}")
            letters[cell] = ch
            owners.setdefault(cell, []).append(e["dir"])
    for cell, dirs in owners.items():
        if len(set(dirs)) < len(dirs):
            problems.append(f"parallel overlap at {cell}")
    for e in p["entries"]:
        dr, dc = (0, 1) if e["dir"] == "a" else (1, 0)
        n = len(e["answer"])
        if (e["r"] - dr, e["c"] - dc) in letters or (e["r"] + dr * n, e["c"] + dc * n) in letters:
            problems.append(f"{e['n']}{e['dir']} blocked ends")
        for i in range(n):
            cell = (e["r"] + dr * i, e["c"] + dc * i)
            if len(owners[cell]) == 1:
                for side in ((cell[0] - dc, cell[1] - dr), (cell[0] + dc, cell[1] + dr)):
                    if side in letters:
                        problems.append(f"touching at {cell}")
    if p["width"] > SIZE or p["height"] > SIZE or len(p["entries"]) < MIN_WORDS:
        problems.append("size or word count")
    return problems


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=400)
    parser.add_argument("--seed", type=int, default=20261013)
    args = parser.parse_args()

    cards = json.loads((ROOT / "Content" / "cards.json").read_text(encoding="utf-8"))["cards"]
    out_dir = ROOT / "Content" / "puzzles"
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    failures = 0

    for level in ["A1", "A2", "B1", "B2", "C1"]:
        words = [(c["word"].upper(), c["id"]) for c in cards
                 if c["level"] == level and "general" in c["decks"] and 3 <= len(c["word"]) <= SIZE]
        if len(words) < 20:
            print(f"{level}: skipped ({len(words)} words)")
            continue
        puzzles = []
        while len(puzzles) < args.count:
            pid = f"{level}-{len(puzzles) + 1:04d}"
            for _ in range(ATTEMPTS):
                p = attempt(words, rng, pid)
                if p:
                    break
            else:
                failures += 1
                continue
            problems = validate(p)
            if problems:
                print(f"invalid {pid}: {problems}", file=sys.stderr)
                sys.exit(1)
            puzzles.append(p)
        path = out_dir / f"{level}.json"
        path.write_text(json.dumps({"level": level, "puzzles": puzzles}, separators=(",", ":")) + "\n", encoding="utf-8")
        avg = sum(len(p["entries"]) for p in puzzles) / len(puzzles)
        print(f"{level}: {len(puzzles)} puzzles from {len(words)} words, {avg:.1f} words each -> {path.relative_to(ROOT)}")
    if failures:
        print(f"{failures} attempt batches failed and were retried")


if __name__ == "__main__":
    main()
