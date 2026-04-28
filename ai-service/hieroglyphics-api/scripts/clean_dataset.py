"""
Clean the AhmedElTaher dataset for training.

Filters for entries that have:
- Gardiner signs
- A translation
- Valid Gardiner format (no braces like {mathematics})

Output: data/training_data_clean.json
"""
import json


def main():
    print("Loading dataset...")
    with open("data/aetel_dataset.json", encoding="utf-8") as f:
        data = json.load(f)
    print(f"Loaded {len(data)} raw entries")

    clean = []
    skipped_braces = 0
    skipped_missing = 0

    for d in data:
        gardiner = d.get("gardiner_signs")
        translation = d.get("translation")

        if not gardiner or not translation:
            skipped_missing += 1
            continue

        if "{" in gardiner:
            skipped_braces += 1
            continue

        clean.append({
            "gardiner": gardiner.strip(),
            "english": translation.strip(),
            "translit": (d.get("transliteration_unicode") or "").strip(),
            "source": d.get("source", ""),
            "split": d.get("split", "train"),
        })

    # Save
    with open("data/training_data_clean.json", "w", encoding="utf-8") as f:
        json.dump(clean, f, ensure_ascii=False, indent=2)

    # Stats
    train = sum(1 for d in clean if d["split"] == "train")
    val = sum(1 for d in clean if d["split"] == "validation")

    print()
    print("=" * 50)
    print("CLEANING REPORT")
    print("=" * 50)
    print(f"Total clean:        {len(clean):>6}")
    print(f"Skipped (braces):   {skipped_braces:>6}")
    print(f"Skipped (missing):  {skipped_missing:>6}")
    print()
    print(f"Train:              {train:>6}")
    print(f"Validation:         {val:>6}")
    print()
    print("First 5 samples:")
    for i, d in enumerate(clean[:5], 1):
        print(f"\n  [{i}] gardiner: {d['gardiner']}")
        print(f"      english:  {d['english'][:80]}")
        print(f"      translit: {d['translit']}")
        print(f"      source:   {d['source']}")

    print(f"\n✅ Saved to data/training_data_clean.json")


if __name__ == "__main__":
    main()