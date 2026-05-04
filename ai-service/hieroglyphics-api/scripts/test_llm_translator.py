"""
Manual smoke test for the LLM Translator Service.

Tests the LLM with several real Gardiner sequences to verify:
1. Famous cartouches (Ramesses, Tut)
2. Deity names (Amun)
3. Common formulas (htp di nsw)
4. Unknown sequences (graceful low-confidence response)

Run from project root:
    python scripts/test_llm_translator.py
"""
import json
import os
import sys
import time
from pathlib import Path


def load_env():
    """Manually load .env file."""
    env_path = Path(".env")
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            os.environ[key.strip()] = value.strip().strip('"').strip("'")


def print_result(label, codes, result):
    """Pretty-print an LLM translation result."""
    print()
    print("=" * 70)
    print(f"TEST: {label}")
    print(f"INPUT: {' '.join(codes)}")
    print("-" * 70)
    if result is None:
        print("❌ Result: None (LLM call failed)")
        return

    print(f"  Translation EN: {result.translation_en}")
    print(f"  Translation AR: {result.translation_ar}")
    print(f"  Transliteration: {result.transliteration}")
    print(f"  Confidence: {result.confidence.value}")
    print(f"  Type: {result.type.value}")
    print(f"  Is complete phrase: {result.is_complete_phrase}")
    if result.warning:
        print(f"  ⚠️  Warning: {result.warning}")
    print(f"  Explanation EN: {result.explanation_en}")
    print(f"  Explanation AR: {result.explanation_ar}")


def main():
    # Load environment variables
    load_env()

    # Make project root importable
    project_root = Path(__file__).parent.parent
    sys.path.insert(0, str(project_root))

    print("=" * 70)
    print("LLM TRANSLATOR SERVICE - MANUAL TEST")
    print("=" * 70)
    print()

    # Initialize the service
    try:
        from api.services.llm_translator_service import LLMTranslatorService
        translator = LLMTranslatorService()
    except Exception as e:
        print(f"❌ Failed to initialize service: {e}")
        return

    print(f"✅ Service initialized")
    print(f"   Model: {translator.model}")
    print(f"   Temperature: {translator.temperature}")
    print()

    # Test cases - covering different inscription types
    test_cases = [
        ("Ramesses II Cartouche (Famous)", ["N5", "S29", "S29", "M23", "X1"]),
        ("Tutankhamun Birth Name", ["M17", "M17", "X1", "N29", "S34", "Y1", "M17", "M17", "N35"]),
        ("Amun (Deity Name)", ["M17", "M17", "N35"]),
        ("Single Glyph - N5 (Ra/Sun)", ["N5"]),
        ("Unknown Random Sequence", ["G1", "V31", "D58", "N17"]),
    ]

    # Run each test
    for i, (label, codes) in enumerate(test_cases, 1):
        try:
            start = time.time()
            result = translator.translate(codes)
            elapsed = time.time() - start
            print_result(label, codes, result)
            print(f"  ⏱️  Time: {elapsed:.2f}s")
        except Exception as e:
            print(f"\n❌ TEST {i} FAILED: {e}")
            import traceback
            traceback.print_exc()

        # Small delay between requests (be nice to Groq)
        if i < len(test_cases):
            time.sleep(1)

    print()
    print("=" * 70)
    print("MANUAL TEST COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    main()