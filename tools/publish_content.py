#!/usr/bin/env python3
"""Write the content GitHub Pages serves to the app: cards.json and its manifest.

The app checks manifest.json at most every six hours (ContentUpdater) and downloads cards.json
when contentVersion is higher than what it has, after checking size and sha256. Bump SCHEMA
(and ContentUpdater.schema in the app) when cards.json changes shape in a way older apps
cannot read; they then keep their content until they are updated.

Usage: python3 tools/publish_content.py site/content   (run by .github/workflows/pages.yml)
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    data = (ROOT / "Content" / "cards.json").read_bytes()
    version = json.loads(data)["contentVersion"]
    (out / "cards.json").write_bytes(data)
    manifest = {"contentVersion": version, "schema": SCHEMA,
                "sha256": hashlib.sha256(data).hexdigest(), "size": len(data)}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"content v{version}, {len(data)} bytes -> {out}")


if __name__ == "__main__":
    main()
