"""
Extract all Gardiner class names from the trained YOLOv8 detector.
Saves them to data/yolo_classes.json for use in icon generation.
"""

import json
from pathlib import Path
from ultralytics import YOLO

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
MODEL_PATH = PROJECT_ROOT / "models" / "detector" / "best.pt"
OUTPUT_PATH = PROJECT_ROOT / "data" / "yolo_classes.json"


def main():
    print(f"Loading YOLO model from: {MODEL_PATH}")
    
    if not MODEL_PATH.exists():
        print(f"❌ ERROR: Model not found at {MODEL_PATH}")
        print("Make sure best.pt is downloaded from Drive")
        return
    
    model = YOLO(str(MODEL_PATH))
    class_names = model.names  # dict: {0: "A1", 1: "A2", ...}
    
    total_classes = len(class_names)
    print(f"✅ Model loaded. Total classes: {total_classes}")
    
    # Sort by class ID for consistency
    sorted_classes = dict(sorted(class_names.items()))
    
    # Show sample
    sample = list(sorted_classes.values())[:20]
    print(f"\n📋 Sample (first 20):")
    for i, code in enumerate(sample):
        print(f"   {i:3d}: {code}")
    
    # Save as JSON
    output_data = {
        "total_classes": total_classes,
        "classes": sorted_classes,  # {0: "A1", 1: "A2", ...}
        "codes_only": list(sorted_classes.values()),  # ["A1", "A2", ...]
    }
    
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Saved to: {OUTPUT_PATH}")
    print(f"   File size: {OUTPUT_PATH.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()