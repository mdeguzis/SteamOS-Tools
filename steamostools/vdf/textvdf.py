"""Brace-delimited text VDF parsing (Valve's KeyValues format), as used in
Steam's config.vdf, libraryfolders.vdf, and appmanifest_*.acf files.

Extracted and generalized from vulkan-shader-util.py's original
`_read_braced_section` (previously private to that one script).

This intentionally does not attempt a full recursive KeyValues parser --
it exposes the two primitives the existing tools actually need (extract a
named brace-delimited section, and pull flat "key" "value" pairs out of a
block) rather than building a generalized parser nothing here uses yet.
Binary shortcuts.vdf (a different format) is out of scope for this module;
see the app-image-manager/update-software conversion batch for that.
"""

from __future__ import annotations

import re


def read_braced_section(text: str, section: str) -> str | None:
    """Return the contents between the braces following `"section"`, or
    None if the section is not present. Handles nested braces."""
    m = re.search(r'"' + re.escape(section) + r'"\s*\n\s*{', text)
    if not m:
        return None
    depth = 1
    i = m.end()
    start = i
    while depth and i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return text[start : i - 1]


def read_kv_pairs(text: str) -> dict[str, str]:
    """Extract flat `"key" "value"` pairs from a KeyValues block (does not
    recurse into nested braces -- callers that need a specific nested
    section should call read_braced_section first)."""
    return dict(re.findall(r'"([^"]+)"\s*\n?\s*"([^"]*)"', text))
