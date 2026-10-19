#!/usr/bin/env python3
"""Build the Gemini prompt that writes one curriculum unit.

The prompt carries the unit's goal, word list and phrases from plan.json, the vocabulary a
unit may use (grammar words, the core, the unit itself), the quality rules learned from the
review rounds, and a finished unit (the café) as the example to copy.

Usage:
  python3 tools/unit_prompt.py A1 a1-family      # writes Content/curriculum/A1/prompts/a1-family.txt
  python3 tools/unit_prompt.py A1 --all          # every unit in the plan
Paste the prompt into AI Studio (a Pro model, temperature about 0.4), save the JSON answer as
Content/curriculum/A1/<unit file>.json and run tools/check_unit.py A1.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_unit import FUNCTION_WORDS, MAX_SENTENCE, MAX_TEXT, MAX_TR  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

GRAMMAR = {
    "any": "A1 grammar only: present simple, present continuous, can/can't, imperatives, "
           "there is/there are, have got is not used (use have).",
    "last": "A1 grammar plus the bridge to A2: past simple of be (was/were), past simple of common "
            "verbs (went, saw, had, did), and be going to for plans.",
}


def compact(unit):
    return json.dumps(unit, ensure_ascii=False, separators=(",", ":"))


def build(level, spec, core, example):
    core_words = ", ".join(w["word"] for w in core["words"])
    core_phrases = " | ".join(p["text"] for p in core["phrases"])
    if spec["placement"] == "last":
        vocab_rule = ("This is the last unit of the level. Examples and stories may use any A1 word: "
                      "the core, every other unit's words, and this unit's words.")
    else:
        vocab_rule = ("Learners may study this unit before any other unit except the core. So every "
                      "example sentence and every story line may use ONLY: the grammar words, the core "
                      "words and phrases, this unit's words and phrases, and names. Nothing else. If a "
                      "sentence needs another word, write a different sentence.")
    return f"""You are a senior English-Turkish lexicographer and an experienced teacher of English to
Turkish speakers. You are writing one unit of a beginner (A1) course in a vocabulary app. Cards
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
- Grammar words: {" ".join(sorted(FUNCTION_WORDS))}
- Core words: {core_words}
- Core phrases: {core_phrases}
- Inflected forms are fine (works, sitting, coffees, children).
- Names: list every person, city, country or language you use in the story's "names" (stories)
  or the unit's "names" (card examples). Use varied Turkish and English first names.

CARDS
- senses: the meanings an A1-A2 learner meets, most common first, at most 3. A sense is one part
  of speech (n, v, adj, adv) with its own meanings and example. Add another sense only if it is
  common at A1-A2.
- tr: 1-3 Turkish meanings, most common first, joined with ", " at most {MAX_TR} characters.
  Synonyms add nothing.
- example_en: natural English that uses the card's word in that sense, at most {MAX_SENTENCE} characters.
  {GRAMMAR[spec["placement"]]}
- example_tr: what a Turkish speaker actually says for example_en: idiomatic, not word for word
  ("I'm cold." is "Üşüyorum.", "Don't worry about it." is "Merak etme."). Nothing added, nothing
  dropped. At most {MAX_SENTENCE} characters.
- note: optional, short Turkish, only for a real trap (irregular plural, false friend, a second
  meaning the learner will meet). Otherwise "".
- Phrase cards: text at most {MAX_TEXT} characters (use "…" for the slot), tr at most {MAX_TR}
  characters, one example that fills the slot.

STORIES
Write 5 short stories (5-8 lines each) that use this unit's words and phrases in real situations.
Different people and places in each: different ages, jobs, cities in Turkey and abroad. Dialogue
is welcome. Each line has the English and a natural Turkish translation. Together the stories
should use most of the unit's words and every phrase. The learner should finish a story and feel
"I can read this".

OUTPUT
Answer with ONLY one JSON object, no text before or after, in exactly this shape (this is a
finished unit; copy its structure, not its content):
{compact(example)}

ids: words "a1-<word>" (spaces become -), phrases "a1-p-<short-slug>", stories "<unit id>-1".."-5".
"""


def main():
    level = sys.argv[1]
    folder = ROOT / "Content" / "curriculum" / level
    plan = json.loads((folder / "plan.json").read_text(encoding="utf-8"))
    core = json.loads((folder / "core.json").read_text(encoding="utf-8"))
    example = json.loads((folder / "cafe.json").read_text(encoding="utf-8"))
    wanted = [u for u in plan["units"] if "--all" in sys.argv or u["id"] in sys.argv[2:]]
    out = folder / "prompts"
    out.mkdir(exist_ok=True)
    for spec in wanted:
        path = out / f"{spec['id']}.txt"
        path.write_text(build(level, spec, core, example), encoding="utf-8")
        print(path.relative_to(ROOT), len(path.read_text(encoding="utf-8")), "chars")


if __name__ == "__main__":
    main()
