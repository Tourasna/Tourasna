"""
Generate PNG icons for all 767 Gardiner codes from the YOLO model.

Strategy:
1. Load YOLO classes (767 codes)
2. Load Gardiner → Unicode mapping (741 direct + 26 variants)
3. For variants (e.g., A14a), use base code's Unicode (A14)
4. Render each Unicode character as 256x256 PNG with transparent background
5. Save to data/glyph_icons/<gardiner_code>.png
"""

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
FONT_PATH = PROJECT_ROOT / "data" / "fonts" / "NotoSansEgyptianHieroglyphs-Regular.ttf"
YOLO_CLASSES_PATH = PROJECT_ROOT / "data" / "yolo_classes.json"
UNICODE_MAP_PATH = PROJECT_ROOT / "data" / "gardiner_unicode_map.json"
OUTPUT_DIR = PROJECT_ROOT / "data" / "glyph_icons"

# Image settings
ICON_SIZE = 256
FONT_SIZE = 200          # ~78% of icon size, leaves padding
TEXT_COLOR = (0, 0, 0, 255)  # Black, fully opaque
BG_COLOR = (0, 0, 0, 0)      # Transparent

# Variant suffixes to strip when finding fallback base code
VARIANT_SUFFIXES = ["a", "b", "c", "v", "V", "A", "B"]


def get_base_code(gardiner_code: str) -> str | None:
    """
    For variant codes (e.g., 'A14a'), return the base code ('A14').
    Returns None if the code doesn't match a variant pattern.
    """
    for suffix in VARIANT_SUFFIXES:
        if gardiner_code.endswith(suffix) and len(gardiner_code) > 1:
            base = gardiner_code[:-len(suffix)]
            # Make sure base ends with a digit (not another letter)
            if base and base[-1].isdigit():
                return base
    return None


def render_glyph(unicode_char: str, font: ImageFont.FreeTypeFont) -> Image.Image:
    """Render a single hieroglyph as a 256x256 PNG with transparent background."""
    img = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Get text bounding box to center it
    bbox = draw.textbbox((0, 0), unicode_char, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Calculate centered position (account for bbox offset)
    x = (ICON_SIZE - text_width) // 2 - bbox[0]
    y = (ICON_SIZE - text_height) // 2 - bbox[1]
    
    draw.text((x, y), unicode_char, font=font, fill=TEXT_COLOR)
    return img


def main():
    print("🎨 Generating glyph icons...")
    print(f"   Font:        {FONT_PATH}")
    print(f"   Output dir:  {OUTPUT_DIR}")
    print(f"   Size:        {ICON_SIZE}x{ICON_SIZE}")
    print()
    
    # Verify font exists
    if not FONT_PATH.exists():
        print(f"❌ Font not found at {FONT_PATH}")
        return
    
    # Load mappings
    with open(YOLO_CLASSES_PATH, "r", encoding="utf-8") as f:
        yolo_codes = json.load(f)["codes_only"]
    
    with open(UNICODE_MAP_PATH, "r", encoding="utf-8") as f:
        unicode_data = json.load(f)
    matched = unicode_data["matched"]  # {code: {unicode_char, ...}}
    
    print(f"📋 Loaded {len(yolo_codes)} Gardiner codes")
    print(f"📋 Direct Unicode matches: {len(matched)}")
    
    # Load font
    font = ImageFont.truetype(str(FONT_PATH), FONT_SIZE)
    print(f"✅ Font loaded: {FONT_SIZE}pt\n")
    
    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Generate icons
    stats = {
        "direct": 0,
        "fallback": 0,
        "failed": 0,
    }
    failed_codes = []
    fallback_codes = []
    
    for code in yolo_codes:
        unicode_char = None
        source = None
        
        # Try direct match
        if code in matched:
            unicode_char = matched[code]["unicode_char"]
            source = "direct"
        else:
            # Try fallback to base code
            base = get_base_code(code)
            if base and base in matched:
                unicode_char = matched[base]["unicode_char"]
                source = "fallback"
                fallback_codes.append(f"{code} → {base}")
        
        if unicode_char is None:
            stats["failed"] += 1
            failed_codes.append(code)
            continue
        
        # Render and save
        img = render_glyph(unicode_char, font)
        output_path = OUTPUT_DIR / f"{code}.png"
        img.save(output_path, "PNG", optimize=True)
        stats[source] += 1
    
    # Summary
    print("📊 Generation Summary:")
    print(f"   ✅ Direct match:     {stats['direct']}")
    print(f"   🔁 Fallback used:    {stats['fallback']}")
    print(f"   ❌ Failed:           {stats['failed']}")
    print(f"   ─────────────────────────")
    print(f"   📦 Total generated:  {stats['direct'] + stats['fallback']}")
    
    if fallback_codes:
        print(f"\n🔁 Fallback mappings:")
        for line in fallback_codes:
            print(f"   {line}")
    
    if failed_codes:
        print(f"\n❌ Failed codes (no Unicode found):")
        for code in failed_codes:
            print(f"   - {code}")
    
    # Folder size
    total_size_kb = sum(f.stat().st_size for f in OUTPUT_DIR.glob("*.png")) / 1024
    print(f"\n💾 Total size: {total_size_kb:.1f} KB ({total_size_kb/1024:.2f} MB)")
    print(f"📁 Files saved to: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()