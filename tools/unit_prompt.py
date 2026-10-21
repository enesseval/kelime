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
GRAMMAR["B1"] = {
    "any": "B1 grammar: everything from A1-A2, present perfect continuous, past perfect, used to, the first "
           "and second conditional, the passive (present and past simple), relative clauses (who, which, "
           "that, where), might/must/can't for guessing, gerund or infinitive after common verbs. No third "
           "conditional, no reported speech.",
    "last": "B1 grammar plus the bridge to B2: second conditional (If I were…), wish + past (I wish I had…), "
            "reported speech (He told me that…), it is said that…, and the past perfect in stories.",
}
GRAMMAR["B1"]["first"] = GRAMMAR["B1"]["any"]
GRAMMAR["B2"] = {
    "any": "B2 grammar: everything from A1-B1, third conditional, wish/if only, reported speech, all common "
           "passive forms, relative clauses with whose/whom, modal perfects (should have, might have, "
           "must have), future continuous and future perfect, gerund and infinitive patterns. No "
           "inversion, no cleft sentences.",
    "last": "B2 grammar plus the bridge to C1: mixed conditionals (If I had…, I would be…), cleft sentences "
            "(What I need is…, It was … that…), not only … but also, would rather, and looking back on events.",
}
GRAMMAR["B2"]["first"] = GRAMMAR["B2"]["any"]
GRAMMAR["C1"] = {
    "any": "C1 grammar: everything from A1-B2, mixed conditionals, cleft sentences (What I need is…, It was … "
           "that…), participle clauses (Having finished…), advanced passives (It is thought that…, He is said "
           "to…), modal perfects, and a formal or neutral register as the context needs. Inversion only in "
           "the bridge unit.",
    "last": "C1 grammar plus the bridge to C2: inversion after negative adverbs (Seldom have I…, No sooner had… "
            "than…, Under no circumstances…), conditional inversion (Were it not for…, Had I known…), and a "
            "formal register for speeches and writing.",
}
GRAMMAR["C1"]["first"] = GRAMMAR["C1"]["any"]
GRAMMAR["A1"]["first"] = GRAMMAR["A1"]["any"]
GRAMMAR["A2"]["first"] = GRAMMAR["A2"]["any"]
NAMES = {"A1": "beginner (A1)", "A2": "elementary (A2)", "B1": "intermediate (B1)", "B2": "upper-intermediate (B2)", "C1": "advanced (C1)"}
SENSE_LEVEL = {"A1": "A1-A2", "A2": "A2-B1", "B1": "B1-B2", "B2": "B2-C1", "C1": "C1-C2"}


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
        # From the plan, so the bridge prompt can be written before the other units come back.
        plan = json.loads((ROOT / "Content" / "curriculum" / level / "plan.json").read_text(encoding="utf-8"))
        others = sorted({w for u in plan["units"] if u["placement"] == "any" for w in u["words"]})
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
- Before you answer, read every example and every story line again word by word and replace
  any word that is not in the lists. This is the most common mistake.
- Check every word against the lists. Even very common words are not allowed unless they are
  listed (question, food, minute, phone, umbrella, coat, sea, back): use a listed word instead.
- Words of OTHER units of this level are not allowed, however common.
- No reporting verbs in stories (says, asks, tells): write dialogue lines directly.
- Names: list every person, city, country or language you use in the story's "names" (stories)
  or the unit's "names" (card examples), countries and languages too (Turkey, English).
  Use varied Turkish and English first names, but not names that are also English words
  (Can, May, Bill, Rose): learners read them as words.

CARDS
- senses: the meanings an {SENSE_LEVEL[level]} learner meets, most common first, at most 3. A sense is one
  part of speech (n, v, adj, adv, prep, conj) with its own meanings and example. Add another sense only if
  it is common at {SENSE_LEVEL[level]}.
- tr: 1-3 Turkish meanings, most common first, joined with ", " at most {MAX_TR} characters.
  Synonyms add nothing.
- example_en: natural English that uses the card's word in that sense, at most {MAX_SENTENCE} characters.
  {GRAMMAR[level][spec["placement"]]}
  Use each word in its natural collocations: every example and story line must be a sentence a
  native speaker would really say (not "prevalent in my head", "a profound nuance", "arranged an
  experiment for a hypothesis"). If the allowed words cannot make a natural sentence, choose a
  simpler situation.
  Do not squeeze core words into sentences where they do not belong (no "a profound dilemma",
  "a profound nostalgia", "a substantial discrepancy in our views"); simple words are fine.
- example_tr: what a Turkish speaker actually says for example_en: idiomatic, not word for word
  ("I'm cold." is "Üşüyorum.", "Don't worry about it." is "Merak etme."). Nothing added, nothing
  dropped: do not add what English leaves open (brother is "kardeş", not "abi", unless the
  sentence says older). Avoid crude or dated words. At most {MAX_SENTENCE} characters.
- note: optional, short Turkish, only for a real trap (irregular past, false friend, a second
  meaning the learner will meet, a confusing pair like say/tell). Otherwise "".
- Idioms and phrases: give the Turkish a native speaker would use, never a word-for-word
  rendering ("Let's agree to disagree." is "Fikirlerimiz farklı, kabul.", not "Anlaşamadığımızda
  anlaşalım."; "Let's take it from here." is "Gerisini biz hallederiz."). Turkish must be
  grammatical everyday Turkish; never coin forms like "dikkate almamazlık etmek".
- Phrase cards: text at most {MAX_TEXT} characters (use "…" for the slot), tr at most {MAX_TR}
  characters, one example that fills the slot. When an example has two speakers, separate
  them with " – " ("I'm hungry. – Me too!").

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
