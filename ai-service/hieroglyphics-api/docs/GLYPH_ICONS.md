# Glyph Icons — Flutter Integration Guide

## Overview

The Tourasna AI service detects Egyptian hieroglyphs and returns their Gardiner classification codes (e.g., `N5`, `A1`, `S29`). The Flutter app displays these glyphs as icons using a bundled set of 767 PNG images.

**Why client-side assets instead of API-served images?**
- ⚡ **Instant rendering** — no network round-trips per glyph
- 📡 **Works offline** — tourists at archaeological sites with poor connectivity
- 💰 **Zero AWS bandwidth cost** — icons load locally
- 🎨 **Smooth UX** — no loading spinners for every glyph

---

## What's Provided

A folder of **767 PNG icons** covering every Gardiner code the YOLO detector can produce:

| Property | Value |
|---|---|
| **Total icons** | 767 |
| **Format** | PNG (RGBA) |
| **Size** | 256×256 pixels |
| **Background** | Transparent |
| **Coverage** | 100% of detector classes |
| **Total ZIP size** | ~3.7 MB |
| **Naming convention** | `<gardiner_code>.png` (e.g., `N5.png`, `A1.png`) |

### Example Files
glyph_icons/
├── A1.png       (man seated  𓀀)
├── A2.png       (man with hand to mouth  𓀁)
├── ...
├── N5.png       (sun disk  𓇳)
├── S29.png      (folded cloth  𓋴)
├── X1.png       (bread loaf  𓏏)
└── Z4.png       (oblique strokes  𓏤)

---

## Integration in Flutter

### Step 1: Add to assets folder

Place the `glyph_icons/` folder inside your Flutter project:
your_flutter_app/
├── assets/
│   └── glyph_icons/
│       ├── A1.png
│       ├── A2.png
│       └── ... (767 files)
├── lib/
└── pubspec.yaml

### Step 2: Register in `pubspec.yaml`

```yaml
flutter:
  assets:
    - assets/glyph_icons/
```

### Step 3: Use in widgets

#### Simple display

```dart
class GlyphIcon extends StatelessWidget {
  final String gardinerCode;
  final double size;

  const GlyphIcon({
    super.key,
    required this.gardinerCode,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/glyph_icons/$gardinerCode.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback for missing icons (shouldn't happen, but safe)
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              gardinerCode,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
```

#### Usage
```dart
GlyphIcon(gardinerCode: 'N5', size: 80)
```

---

## Use Case 1: Display Detected Glyphs

After calling `POST /api/translate`, the response contains a list of detections. Use the `gardiner_code` field to display each one:

```dart
ListView.builder(
  scrollDirection: Axis.horizontal,
  itemCount: response.detections.length,
  itemBuilder: (context, index) {
    final detection = response.detections[index];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          GlyphIcon(gardinerCode: detection.gardinerCode, size: 64),
          Text(
            'Conf: ${(detection.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  },
)
```

---

## Use Case 2: Show Alternatives for Low-Confidence Detections

When a detection's `confidence < 0.60`, the API returns `alternatives` (top-K candidates). Show a picker so the user can select the correct one:

```dart
class GlyphAlternativesPicker extends StatelessWidget {
  final Detection detection;
  final ValueChanged<String> onSelect;

  const GlyphAlternativesPicker({
    super.key,
    required this.detection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (!detection.isAmbiguous) {
      return GlyphIcon(gardinerCode: detection.gardinerCode);
    }

    return Row(
      children: [
        // Main detection
        _buildOption(
          gardinerCode: detection.gardinerCode,
          confidence: detection.confidence,
          isSelected: true,
        ),
        const SizedBox(width: 8),
        const Text('or'),
        const SizedBox(width: 8),
        // Alternatives
        ...detection.alternatives.map((alt) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildOption(
            gardinerCode: alt.gardinerCode,
            confidence: alt.confidence,
            isSelected: false,
          ),
        )),
      ],
    );
  }

  Widget _buildOption({
    required String gardinerCode,
    required double confidence,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelect(gardinerCode),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            GlyphIcon(gardinerCode: gardinerCode, size: 56),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Use Case 3: Detailed Sign Information

After calling `GET /api/sign/{code}/info`, display the icon alongside the metadata:

```dart
Row(
  children: [
    GlyphIcon(gardinerCode: signInfo.code, size: 96),
    const SizedBox(width: 16),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(signInfo.code, style: Theme.of(context).textTheme.headlineMedium),
          Text(signInfo.meaning),
          if (signInfo.transliteration != null)
            Text('Sound: ${signInfo.transliteration}'),
        ],
      ),
    ),
  ],
)
```

---

## Performance Notes

- **App size impact:** +3.7 MB. Consider lazy-loading or splitting into a separate package if size matters.
- **Memory:** Each PNG is small (~5 KB). Flutter caches loaded images automatically.
- **Recommended display size:** 48–96 px for thumbnails, up to 256 px for detail views (no upscaling needed).

---

## License

The hieroglyph PNG icons are derived from the **Noto Sans Egyptian Hieroglyphs** font, which is licensed under the **SIL Open Font License (OFL) 1.1**. The license is included in the assets folder (`OFL.txt`) and must be retained.

This means:
- ✅ Free for commercial use
- ✅ Free to redistribute
- ✅ Free to modify
- ⚠️ License file must accompany the assets

---

## Where to Get the Icons

The full set of 767 PNG icons (3.7 MB ZIP) is available on Google Drive:
**📥 Download Link:** [glyph_icons.zip](https://drive.google.com/file/d/1KuscWdU8HfPyq6dYwWf0QCaNNqz5stqE/view?usp=sharing)


Inside the ZIP:
glyph_icons.zip
├── glyph_icons/        ← 767 PNG files
│   ├── A1.png
│   └── ...
└── OFL.txt             ← License (required)

---

## Questions?

For backend integration questions, see [`API.md`](./API.md).
For model behavior questions, contact the AI team.