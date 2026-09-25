"""Merges mobile-only strings into lib/l10n/mobile/{en,si,ta}.json.

Usage: python tool/add_mobile_strings.py strings.json

strings.json maps dotted keys to their three translations:
  {"auth.login.pendingTitle": {"en": "...", "si": "...", "ta": "..."}}

Existing keys are overwritten. Then run `dart run tool/import_web_translations.dart`.
"""

import json
import sys

LANGUAGES = ["en", "si", "ta"]


def set_path(tree, dotted, value):
    parts = dotted.split(".")
    node = tree
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    node[parts[-1]] = value


def main(path):
    with open(path, encoding="utf-8") as handle:
        additions = json.load(handle)
    for language in LANGUAGES:
        target = f"lib/l10n/mobile/{language}.json"
        with open(target, encoding="utf-8") as handle:
            tree = json.load(handle)
        for key, translations in additions.items():
            set_path(tree, key, translations[language])
        with open(target, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(tree, ensure_ascii=False, indent=2) + "\n")
    print(f"Added {len(additions)} strings to {len(LANGUAGES)} languages.")


if __name__ == "__main__":
    main(sys.argv[1])
