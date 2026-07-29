#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fail when Colorvia's String Catalog or localized call sites are incomplete."""

import json
import re
import sys
from pathlib import Path


CATALOG_PATH = Path("Colorvia/Resources/Localizable.xcstrings")
SOURCE_ROOT = Path("Colorvia")
EXPECTED_LANGUAGES = {
    "en",
    "ja",
    "es",
    "fr",
    "de",
    "it",
    "pt-BR",
    "ko",
    "zh-Hans",
    "zh-Hant",
    "ru",
}
ALLOWED_RAW_UI_STRINGS = {
    "Colorvia",
    "©︎ Colorvia",
    "COLORVIA",
    "Natural Earth",
    "Insee COG 2026",
    "Geolonia Japanese Addresses",
    "GeoNames",
    "U.S. Census Bureau",
    "Singapore URA",
    "OK",
}
UI_LITERAL_PATTERN = re.compile(
    r'(?:Text|Button|Section|navigationTitle|accessibilityLabel|LabeledContent)\("([^"]+)"'
)
LOCALIZATION_KEY_PATTERN = re.compile(r'L10n\.text\("([^"]+)"\)')
FORMAT_PATTERN = re.compile(r"%(?:\d+\$)?[-+#0 ]*\d*(?:\.\d+)?[a-zA-Z@]")


def fail(errors):
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    raise SystemExit(1)


def main():
    errors = []
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    strings = catalog.get("strings", {})

    for key, entry in strings.items():
        localizations = entry.get("localizations", {})
        languages = set(localizations)
        missing_languages = EXPECTED_LANGUAGES - languages
        unexpected_languages = languages - EXPECTED_LANGUAGES
        if missing_languages:
            errors.append(f"{key} is missing languages: {sorted(missing_languages)}")
        if unexpected_languages:
            errors.append(f"{key} has unexpected languages: {sorted(unexpected_languages)}")

        source_value = (
            localizations.get("en", {}).get("stringUnit", {}).get("value", "")
        )
        source_formats = FORMAT_PATTERN.findall(source_value)
        for language in EXPECTED_LANGUAGES:
            unit = localizations.get(language, {}).get("stringUnit", {})
            value = unit.get("value", "").strip()
            if unit.get("state") != "translated":
                errors.append(f"{key} [{language}] is not marked translated")
            if not value:
                errors.append(f"{key} [{language}] is empty")
            if FORMAT_PATTERN.findall(value) != source_formats:
                errors.append(
                    f"{key} [{language}] format placeholders differ from English"
                )

    referenced_keys = set()
    for source_path in SOURCE_ROOT.rglob("*.swift"):
        source = source_path.read_text(encoding="utf-8")
        referenced_keys.update(LOCALIZATION_KEY_PATTERN.findall(source))
        for literal in UI_LITERAL_PATTERN.findall(source):
            # Skip interpolations / nested quotes that the naive scanner catches.
            if "\\(" in literal:
                continue
            if literal not in ALLOWED_RAW_UI_STRINGS:
                errors.append(
                    f'{source_path}: raw UI string "{literal}" must use L10n.text'
                )

    missing_keys = referenced_keys - set(strings)
    if missing_keys:
        errors.append(f"code references missing catalog keys: {sorted(missing_keys)}")

    if errors:
        fail(errors)

    print(
        f"Validated {len(strings)} keys across {len(EXPECTED_LANGUAGES)} languages "
        f"and {len(referenced_keys)} referenced keys."
    )


if __name__ == "__main__":
    main()
