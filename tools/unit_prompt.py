#!/usr/bin/env python3
"""Build the Gemini prompt that writes one curriculum unit.

The prompt carries the unit's goal, word list and phrases from plan.json, the vocabulary a
unit may use (grammar words, the core, the unit itself), the quality rules learned from the
review rounds, and a finished unit (the café) as the example to copy.

Usage:
  python3 tools/unit_prompt.py A1 a1-family      # writes Content/curriculum/A1/prompts/a1-family.txt
  python3 tools/unit_prompt.py A2 a2-core        # a level's core comes first
  python3 tools/unit_prompt.py A1 --all          # every unit in the plan (the core must exist)
From A2 on, learners know every earlier level, so its words and phrases are allowed too.
Paste the prompt into AI Studio (a Pro model, temperature about 0.4), save the JSON answer as
Content/curriculum/A1/<unit file>.json and run tools/check_unit.py A1.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_unit import MAX_SENTENCE, MAX_TEXT, MAX_TR, earlier  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

GRAMMAR = {
    "A1": {
        "any": "A1 grammar only: present simple, present continuous, can/can't, imperatives, "
               "there is/there are, have got is not used (use have).",
        "last": "A1 grammar plus the bridge to A2: past simple of be (was/were), past simple of common "
                "verbs (went, saw, had, did), and be going to for plans.",
    },
    "A2": {
        "any": "A2 grammar: everything from A1, past simple (regular and common irregular verbs), past "
               "continuous, present perfect with ever/never/just/already/yet, comparatives and "
               "superlatives, will and be going to, should, have to, must, could for requests. No "
               "conditionals, no passive, no reported speech.",
        "last": "A2 grammar plus the bridge to B1: past continuous and past simple together to tell a story "
                "(I was walking when…), the first conditional (If it rains, we'll…), and time words "
                "(suddenly, then, finally, while, during).",
    },
}
GRAMMAR["A1"]["first"] = GRAMMAR["A1"]["any"]
GRAMMAR["A2"]["first"] = GRAMMAR["A2"]["any"]
NAMES = {"A1": "beginner (A1)", "A2": "elementary (A2)", "B1": "intermediate (B1)"}
SENSE_LEVEL = {"A1": "A1-A2", "A2": "A2-B1", "B1": "B1-B2"}


def compact(unit):
    return json.dumps(unit, ensure_ascii=False, separators=(",", ":"))


def build(level, spec, core, example):
    prior_vocab, function_words, prior_words = earlier(level)
    prefix = level.lower()
    known = ""
    if prior_vocab:
        known = ("- Earlier levels (learners know all of it): " + ", ".join(sorted(prior_words)) + ". "
                 "Their phrases too. Inflected forms are fine.\n")
    core_lines = ""
    if core:
        core_lines = (f"- {level} core words: " + ", ".join(w["word"] for w in core["words"]) + "\n"
                      f"- {level} core phrases: " + " | ".join(p["text"] for p in core["phrases"]) + "\n")
    if spec["placement"] == "last":
        folder = ROOT / "Content" / "curriculum" / level
        others = sorted({w["word"] for f in folder.glob("*.json") if f.stem not in ("plan", "core")
                         for w in json.loads(f.read_text(encoding="utf-8"))["words"]})
        vocab_rule = ("This is the last unit of the level; learners have finished every other unit. "
                      "Examples and stories may use the grammar words, earlier levels, the core, this unit's "
                      "words and phrases, names, and these words from the other units: " + ", ".join(others) + ". "
                      "Nothing else.")
    elif spec["placement"] == "first":
        vocab_rule = ("This is the core: every learner studies it first. Every example sentence and every "
                      "story line may use ONLY: the grammar words, earlier levels, this unit's words and "
                      "phrases, and names. Nothing else. If a sentence needs another word, write a "
                      "different sentence.")
    else:
        vocab_rule = ("Learners may study this unit before any other unit except the core. So every "
                      "example sentence and every story line may use ONLY: the grammar words, earlier "
                      "levels, the core words and phrases, this unit's words and phrases, and names. "
                      "Nothing else. If a sentence needs another word, write a different sentence.")
    stories = 3 if spec["placement"] == "first" else 5
    return f"""You are a senior English-Turkish lexicographer and an experienced teacher of English to
Turkish speakers. You are writing one unit of an {NAMES[level]} course in a vocabulary app. Cards
are shown on the iPhone lock screen, so every text is short. Learners are Turkish speakers.

UNIT
id: {spec["id"]}
title: {spec["title"]}
placement: {spec["placement"]}
goal (what the learner can do after this unit): {spec["goal"]}
words (write one card for each, in this order): {", ".join(spec["words"])}
phrases (write one phrase card for each; you may polish the wording): {" | ".join(spec["phrases"])}

VOCABULARY RULE
{vocab_rule}
- Grammar words: {" ".join(sorted(function_words))}
{known}{core_lines}- Inflected forms are fine (works, sitting, coffees, children, colder).
- Words of OTHER units of this level are not allowed, however common.
- No reporting verbs in stories (says, asks, tells): write dialogue lines directly.
- Names: list every person, city, country or language you use in the story's "names" (stories)
  or the unit's "names" (card examples), countries and languages too (Turkey, English).
  Use varied Turkish and English first names, but not names that are also English words
  (Can, May, Bill, Rose): learners read them as words.

CARDS
- senses: the meanings an {SENSE_LEVEL[level]} learner meets, most common first, at most 3. A sense is one
  part of speech (n, v, adj, adv, prep) with its own meanings and example. Add another sense only if
  it is common at {SENSE_LEVEL[level]}.
- tr: 1-3 Turkish meanings, most common first, joined with ", " at most {MAX_TR} characters.
  Synonyms add nothing.
- example_en: natural English that uses the card's word in that sense, at most {MAX_SENTENCE} characters.
  {GRAMMAR[level][spec["placement"]]}
- example_tr: what a Turkish speaker actually says for example_en: idiomatic, not word for word
  ("I'm cold." is "Üşüyorum.", "Don't worry about it." is "Merak etme."). Nothing added, nothing
  dropped: do not add what English leaves open (brother is "kardeş", not "abi", unless the
  sentence says older). Avoid crude or dated words. At most {MAX_SENTENCE} characters.
- note: optional, short Turkish, only for a real trap (irregular past, false friend, a second
  meaning the learner will meet, a confusing pair like say/tell). Otherwise "".
- Phrase cards: text at most {MAX_TEXT} characters (use "…" for the slot), tr at most {MAX_TR}
  characters, one example that fills the slot.

STORIES
Write {stories} short stories (5-8 lines each) that use this unit's words and phrases in real situations.
Different people and places in each: different ages, jobs, cities in Turkey and abroad. Dialogue
is welcome. Each line has the English and a natural Turkish translation. Together the stories
should use most of the unit's words and every phrase. The learner should finish a story and feel
"I can read this".

OUTPUT
Answer with ONLY one valid JSON object, no text before or after. Inside strings, write quotes
as \\" or use ‘ ’. Use exactly this shape (this is a finished A1 unit; copy its structure, not its
content or its level):
{compact(example)}

ids: words "{prefix}-<word>" (spaces become -), phrases "{prefix}-p-<short-slug>", stories "<unit id>-1".."-{stories}".
"""


def main():
    level = sys.argv[1]
    folder = ROOT / "Content" / "curriculum" / level
    plan = json.loads((folder / "plan.json").read_text(encoding="utf-8"))
    core_path = folder / "core.json"
    core = json.loads(core_path.read_text(encoding="utf-8")) if core_path.exists() else None
    example = json.loads((ROOT / "Content" / "curriculum" / "A1" / "cafe.json").read_text(encoding="utf-8"))
    wanted = [u for u in plan["units"] if "--all" in sys.argv or u["id"] in sys.argv[2:]]
    out = folder / "prompts"
    out.mkdir(exist_ok=True)
    for spec in wanted:
        path = out / f"{spec['id']}.txt"
        path.write_text(build(level, spec, core, example), encoding="utf-8")
        print(path.relative_to(ROOT), len(path.read_text(encoding="utf-8")), "chars")


if __name__ == "__main__":
    main()
