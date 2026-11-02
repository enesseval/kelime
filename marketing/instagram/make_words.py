"""Writes words.js: the cards the Instagram scenes use, straight from Content/cards.json."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
cards = {c["word"]: c for c in json.load(open(root / "Content/cards.json"))["cards"]}
POS = {"adj": "sıfat", "n": "isim", "v": "fiil", "adv": "zarf", "conj": "bağlaç", "prep": "edat", "phrase": "kalıp"}
WORDS = """hypothesis reluctant resilient entail significant consequence inevitable comprehensive
substantial plausible curious ineffable""".split()
out = {}
for w in WORDS:
    c = cards[w]
    out[w] = {"word": w, "pos": POS[c["pos"]], "tr": ", ".join(c["tr"][:2]), "tr1": c["tr"][0],
              "ex": c.get("example_en", ""), "exTr": c.get("example_tr", ""), "level": c["level"],
              "decks": c.get("decks", [])}
(pathlib.Path(__file__).parent / "words.js").write_text("const W = " + json.dumps(out, ensure_ascii=False, indent=1) + ";\n")
print("\n".join(f'{w}: {v["pos"]} · {v["tr"]} · {v["decks"]}' for w, v in out.items()))
