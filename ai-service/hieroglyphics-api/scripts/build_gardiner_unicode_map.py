"""
Build a complete Gardiner code → Unicode codepoint mapping.

Strategy:
1. Iterate all 1,071 codepoints in the Egyptian Hieroglyphs Unicode block
2. Parse the official Unicode name to extract the Gardiner code
3. Match against the YOLO classes (767 codes)
4. Output: data/gardiner_unicode_map.json
"""

import json
import re
import unicodedata
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
YOLO_CLASSES_PATH = PROJECT_ROOT / "data" / "yolo_classes.json"
OUTPUT_PATH = PROJECT_ROOT / "data" / "gardiner_unicode_map.json"

# Unicode range for Egyptian Hieroglyphs
UNICODE_START = 0x13000
UNICODE_END = 0x1342F

# Regex to parse "EGYPTIAN HIEROGLYPH A001" → "A1"
# Names follow: "EGYPTIAN HIEROGLYPH <CATEGORY><NUMBER><OPTIONAL_SUFFIX>"
NAME_PATTERN = re.compile(
    r"EGYPTIAN HIEROGLYPH\s+([A-Z][A-Z]?)(\d+)([A-Z]*)",
    re.IGNORECASE
)


def parse_gardiner_from_name(name: str) -> str | None:
    """
    Convert Unicode name to Gardiner code.
    
    Examples:
        "EGYPTIAN HIEROGLYPH A001"   → "A1"
        "EGYPTIAN HIEROGLYPH A001A"  → "A1A"
        "EGYPTIAN HIEROGLYPH AA001"  → "Aa1"
        "EGYPTIAN HIEROGLYPH N005"   → "N5"
    """
    match = NAME_PATTERN.match(name)
    if not match:
        return None
    
    category, number, suffix = match.groups()
    # Strip leading zeros from number
    number_int = int(number)
    
    # Handle "Aa" double-letter category (special case)
    # Unicode uses "AA" but Gardiner uses "Aa"
    if category.upper() == "AA":
        category = "Aa"
    else:
        category = category.upper()
    
    code = f"{category}{number_int}"
    if suffix:
        code += suffix.upper()
    
    return code


def build_mapping() -> dict:
    """Build Gardiner code → Unicode codepoint mapping for all hieroglyphs."""
    mapping = {}
    skipped = []
    
    for codepoint in range(UNICODE_START, UNICODE_END + 1):
        char = chr(codepoint)
        try:
            name = unicodedata.name(char)
        except ValueError:
            # Codepoint has no assigned name (reserved/unassigned)
            skipped.append(hex(codepoint))
            continue
        
        gardiner_code = parse_gardiner_from_name(name)
        if gardiner_code:
            mapping[gardiner_code] = {
                "unicode_char": char,
                "unicode_codepoint": f"U+{codepoint:05X}",
                "unicode_decimal": codepoint,
                "unicode_name": name,
            }
    
    return mapping, skipped


def main():
    print("🔨 Building Gardiner → Unicode mapping...")
    print(f"   Range: U+{UNICODE_START:05X} to U+{UNICODE_END:05X}")
    print()
    
    # Load YOLO classes
    if not YOLO_CLASSES_PATH.exists():
        print(f"❌ Run extract_yolo_classes.py first!")
        return
    
    with open(YOLO_CLASSES_PATH, "r", encoding="utf-8") as f:
        yolo_data = json.load(f)
    yolo_codes = set(yolo_data["codes_only"])
    print(f"✅ Loaded {len(yolo_codes)} Gardiner codes from YOLO model")
    
    # Build full Unicode mapping
    full_mapping, skipped = build_mapping()
    print(f"✅ Built Unicode mapping: {len(full_mapping)} hieroglyphs found")
    print(f"   Skipped (unassigned): {len(skipped)} codepoints")
    
    # Cross-reference with YOLO classes
    matched = {code: info for code, info in full_mapping.items() if code in yolo_codes}
    missing_in_unicode = yolo_codes - set(full_mapping.keys())
    
    print()
    print(f"📊 Coverage Analysis:")
    print(f"   YOLO codes total:      {len(yolo_codes)}")
    print(f"   Matched in Unicode:    {len(matched)}")
    print(f"   Missing in Unicode:    {len(missing_in_unicode)}")
    print(f"   Coverage:              {len(matched)/len(yolo_codes)*100:.1f}%")
    
    if missing_in_unicode:
        sample = sorted(missing_in_unicode)[:20]
        print(f"\n⚠️  Missing codes (first 20):")
        for code in sample:
            print(f"   - {code}")
    
    # Show sample matches
    print(f"\n✨ Sample matches:")
    sample_keys = sorted(matched.keys())[:10]
    for code in sample_keys:
        info = matched[code]
        print(f"   {code:6s} → {info['unicode_char']} ({info['unicode_codepoint']})")
    
    # Save output
    output_data = {
        "total_yolo_codes": len(yolo_codes),
        "total_matched": len(matched),
        "total_missing": len(missing_in_unicode),
        "coverage_percent": round(len(matched)/len(yolo_codes)*100, 2),
        "matched": matched,
        "missing": sorted(missing_in_unicode),
    }
    
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Saved to: {OUTPUT_PATH}")
    print(f"   File size: {OUTPUT_PATH.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()