#!/usr/bin/env python3
"""Check curriculum units in Content/curriculum/<LEVEL>/.

A unit may be studied in any order, so every example sentence and every story in it may use
only:
  - everything from earlier levels (an A2 learner knows all of A1),
  - the level's grammar words (FUNCTION_WORDS: pronouns, articles, be, can, prepositions...),
    which learners pick up inside the phrases rather than as cards,
  - the core unit's words and phrases (everyone studies the core first),
  - the unit's own words and phrases,
  - the names a story lists in "names", and the unit's "names" (people, countries,
    languages used in its card examples).
Words are matched after simple English inflection is stripped (works, coffees, sits).

Also checks the lock-screen limits: word and phrase texts <= 28 characters, Turkish meanings
joined <= 28, sentences <= 55.

Also flags a word that already has a card at an earlier level (add a sense there instead).

Usage: python3 tools/check_unit.py [A1|A2]
Exits with status 1 on any problem.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_TEXT, MAX_TR, MAX_SENTENCE = 28, 28, 55

FUNCTION_WORDS = set("""
i you he she it we they me him her us them my your his its our their
a an the this that these those some
am is are be do does did don't doesn't isn't aren't not no yes ok oh
and but or so too very also
in on at to from for with of by about out up down off
here there what where who how when which
can can't please
i'm you're he's she's it's we're they're that's what's where's i'd we'd let's
much many one
""".split())

# Grammar words a level adds; a level may use its own and every earlier level's.
LEVEL_FUNCTION_WORDS = {
    "A2": set("""
will won't would wouldn't should shouldn't could couldn't must mustn't
if than more most any every all both each other another
someone something anything nothing everyone everything somebody nobody
into through over under between behind until since
i've you've we've they've he'd she'd you'd they'd i'll you'll he'll she'll we'll they'll it'll
wasn't weren't didn't hasn't haven't there's here's
why only lot inside outside back ok then first soon later as
""".split()),
}
LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]

IRREGULAR = {
    "children": "child", "people": "people", "men": "man", "women": "woman",
    "has": "have", "had": "have", "goes": "go", "went": "go", "does": "do",
    "came": "come", "saw": "see", "knew": "know", "ate": "eat", "drank": "drink",
    "sat": "sit", "paid": "pay", "spoke": "speak", "swam": "swim", "bought": "buy",
    "sang": "sing", "slept": "sleep", "sold": "sell", "made": "make", "got": "get",
    "took": "take", "felt": "feel", "met": "meet", "left": "left", "understood": "understand",
    "thought": "think", "said": "say", "told": "tell", "gave": "give", "brought": "bring",
    "found": "find", "forgot": "forget", "chose": "choose", "grew": "grow", "stole": "steal",
    "lost": "lose", "began": "begin", "became": "become", "broke": "broken", "fell": "fall",
    "flew": "fly", "wrote": "write", "won": "win", "ran": "run", "drove": "drive", "rode": "ride",
    "wore": "wear", "kept": "keep", "sent": "send", "spent": "spend", "built": "build",
    "taught": "teach", "caught": "catch", "heard": "hear", "held": "hold", "hurt": "hurt",
    "put": "put", "cut": "cut", "let": "let", "woke": "wake", "forgotten": "forget",
    "been": "be", "done": "do", "gone": "go", "seen": "see", "eaten": "eat", "written": "write",
    "taken": "take", "given": "give", "known": "know", "flown": "fly", "chosen": "choose",
    "grown": "grow", "stolen": "steal", "driven": "drive", "spoken": "speak", "got": "get",
    "better": "better", "best": "best", "worse": "worse", "worst": "worse",
}


def lower(text):
    """Lowercase that keeps Turkish İ intact (İzmir -> izmir, not i̇zmir)."""
    return text.replace("İ", "I").lower()


def tokens(text):
    return re.findall(r"[^\W\d_]+(?:'[^\W\d_]+)?", lower(text))


def lemmas(word):
    """Possible base forms of `word`."""
    if word in IRREGULAR:
        return {IRREGULAR[word]}
    out = {word}
    if word.endswith("'s"):
        out.add(word[:-2])
    for suffix, repl in (("ies", "y"), ("es", ""), ("s", ""), ("ied", "y"), ("ed", ""), ("ed", "e"),
                         ("ing", ""), ("ing", "e"), ("ier", "y"), ("iest", "y"), ("er", ""),
                         ("er", "e"), ("est", ""), ("est", "e"), ("ily", "y"), ("ly", "")):
        if word.endswith(suffix) and len(word) > len(suffix) + 2:
            out.add(word[: -len(suffix)] + repl)
    # doubled consonant: sitting -> sit, stopped -> stop
    for form in list(out):
        if len(form) > 3 and form[-1] == form[-2]:
            out.add(form[:-1])
    return out


def vocabulary(unit):
    vocab = set()
    for w in unit.get("words", []):
        vocab |= set(tokens(w["word"]))
    for p in unit.get("phrases", []):
        vocab |= set(tokens(p["text"]))
    return vocab


def load_units(level):
    folder = ROOT / "Content" / "curriculum" / level
    return {p.stem: json.loads(p.read_text(encoding="utf-8"))
            for p in sorted(folder.glob("*.json")) if p.stem != "plan"}


def earlier(level):
    """Vocabulary, grammar words and card words of every level before `level`."""
    vocab, function, words = set(), set(FUNCTION_WORDS), {}
    for lower_level in LEVELS[: LEVELS.index(level)]:
        function |= LEVEL_FUNCTION_WORDS.get(lower_level, set())
        for unit in load_units(lower_level).values():
            vocab |= vocabulary(unit)
            for w in unit.get("words", []):
                words[lower(w["word"])] = w["id"]
    return vocab, function | LEVEL_FUNCTION_WORDS.get(level, set()), words


def check(level):
    units = load_units(level)
    prior_vocab, function_words, prior_words = earlier(level)
    core = next((u for u in units.values() if u.get("placement") == "first"), None)
    core_vocab = vocabulary(core) if core else set()
    level_vocab = set().union(*(vocabulary(u) for u in units.values())) if units else set()
    problems, seen = [], {}

    for name, unit in units.items():
        unit_names = {t for n in unit.get("names", []) for t in tokens(n)}
        # The bridge unit comes last, so it may use the whole level.
        base = level_vocab if unit.get("placement") == "last" else core_vocab | vocabulary(unit)
        allowed = function_words | prior_vocab | base | unit_names

        def unknown(text, extra=()):
            bad = []
            for t in tokens(text):
                forms = lemmas(t)
                if not (forms & allowed) and not (forms & set(extra)):
                    bad.append(t)
            return bad

        def limit(text, n, what):
            if len(text) > n:
                problems.append(f"{name}: {what} is {len(text)} chars (max {n}): {text}")

        for w in unit.get("words", []):
            # A word may sit in several units (table, pay), as one identical card.
            if w["id"] in seen and seen[w["id"]] != w:
                problems.append(f"{name}: {w['id']} differs from the card with the same id in another unit")
            seen[w["id"]] = w
            if lower(w["word"]) in prior_words:
                problems.append(f"{name}: {w['word']} already has a card ({prior_words[lower(w['word'])]}); add a sense there")
            limit(w["word"], MAX_TEXT, f"word {w['id']}")
            if not w.get("senses"):
                problems.append(f"{name}: {w['id']} has no senses")
            for s in w.get("senses", []):
                limit(", ".join(s["tr"]), MAX_TR, f"{w['id']} tr")
                limit(s["example_en"], MAX_SENTENCE, f"{w['id']} example_en")
                limit(s["example_tr"], MAX_SENTENCE, f"{w['id']} example_tr")
                used = {l for t in tokens(s["example_en"]) for l in lemmas(t) | {t}}
                if not set(tokens(w["word"])) & used:
                    problems.append(f"{name}: {w['id']} example does not use the word: {s['example_en']}")
                if bad := unknown(s["example_en"]):
                    problems.append(f"{name}: {w['id']} example uses {bad}: {s['example_en']}")
        for p in unit.get("phrases", []):
            if p["id"] in seen and seen[p["id"]] != p:
                problems.append(f"{name}: {p['id']} differs from the phrase with the same id in another unit")
            seen[p["id"]] = p
            limit(p["text"], MAX_TEXT, f"phrase {p['id']}")
            limit(p["tr"], MAX_TR, f"{p['id']} tr")
            limit(p["example_en"], MAX_SENTENCE, f"{p['id']} example_en")
            limit(p["example_tr"], MAX_SENTENCE, f"{p['id']} example_tr")
            if bad := unknown(p["example_en"]):
                problems.append(f"{name}: {p['id']} example uses {bad}: {p['example_en']}")
        for story in unit.get("stories", []):
            names = {t for n in story.get("names", []) for t in tokens(n)}
            for line in story["lines"]:
                if bad := unknown(line["en"], names):
                    problems.append(f"{name}: story {story['id']} uses {bad}: {line['en']}")

    for name, unit in units.items():
        n_words, n_phrases = len(unit.get("words", [])), len(unit.get("phrases", []))
        n_stories = len(unit.get("stories", []))
        print(f"{name}: {n_words} words, {n_phrases} phrases, {n_stories} stories")
    return problems


def main():
    level = sys.argv[1] if len(sys.argv) > 1 else "A1"
    problems = check(level)
    for p in problems:
        print("  ✗", p)
    print("OK" if not problems else f"{len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
