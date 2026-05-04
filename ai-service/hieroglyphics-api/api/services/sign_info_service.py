"""
Sign Information Service.

Provides detailed information about Gardiner signs by combining:
1. Basic info from translations_db.json (en, ar, sound, category)
2. Extended info from sign_extended_info.json (confusions, examples, notes)

This service powers the interactive correction UI:
- Tourist taps a detected glyph to learn more about it
- Tourist searches for a sign by name when manually correcting
- UI shows visually-similar signs as alternative suggestions

Part of Improvement #1: Interactive Correction (Human-in-the-Loop).
"""
import json
from pathlib import Path
from typing import Dict, List, Optional

from loguru import logger

from api.schemas import SignInfoDetailed, SignSearchResult


# Mapping from Gardiner letter → human-readable category name
# Used when the basic data only has a short category like "humans"
GARDINER_CATEGORIES = {
    "A": "Humans (men and their occupations)",
    "B": "Women and their occupations",
    "C": "Anthropomorphic deities",
    "D": "Body parts",
    "E": "Mammals",
    "F": "Parts of mammals",
    "G": "Birds",
    "H": "Parts of birds",
    "I": "Amphibians and reptiles",
    "K": "Fish and parts of fish",
    "L": "Invertebrates and lesser animals",
    "M": "Trees and plants",
    "N": "Sky, earth, water",
    "O": "Buildings and parts",
    "P": "Ships and parts",
    "Q": "Domestic furniture",
    "R": "Temple furniture and emblems",
    "S": "Crowns, dress, staves",
    "T": "Warfare, hunting, butchery",
    "U": "Agriculture, crafts, professions",
    "V": "Rope, baskets, bags",
    "W": "Vessels of stone and earthenware",
    "X": "Loaves and cakes",
    "Y": "Writing, games, music",
    "Z": "Strokes, signs derived from hieratic, geometrical figures",
    "Aa": "Unclassified signs",
}


class SignInfoService:
    """
    Service for retrieving detailed information about Gardiner signs.

    Loads data from two JSON files at startup and merges them into a
    single in-memory dictionary for fast lookups.
    """

    def __init__(
        self,
        translations_db_path: Path,
        extended_info_path: Path,
    ):
        """
        Initialize the service by loading and merging the two data sources.

        Args:
            translations_db_path: Path to translations_db.json
            extended_info_path: Path to sign_extended_info.json
        """
        self._signs: Dict[str, dict] = {}
        self._load_data(translations_db_path, extended_info_path)
        logger.info(
            "SignInfoService loaded {} signs ({} with extended info)",
            len(self._signs),
            sum(1 for s in self._signs.values() if s.get("has_extended")),
        )

    def _load_data(
        self,
        translations_db_path: Path,
        extended_info_path: Path,
    ) -> None:
        """Load and merge the two data sources."""
        # Load basic info from translations_db.json
        with open(translations_db_path, "r", encoding="utf-8") as f:
            translations_data = json.load(f)
        sign_meanings = translations_data.get("sign_meanings", {})

        # Load extended info
        extended_data = {}
        if extended_info_path.exists():
            with open(extended_info_path, "r", encoding="utf-8") as f:
                extended_full = json.load(f)
            extended_data = extended_full.get("signs", {})
        else:
            logger.warning(
                "Extended info file not found at {}, using basic info only",
                extended_info_path,
            )

        # Merge: every sign in translations_db gets an entry,
        # extended info is overlaid where available.
        for code, basic in sign_meanings.items():
            extended = extended_data.get(code, {})
            self._signs[code] = {
                "code": code,
                "name_en": basic.get("en", ""),
                "name_ar": basic.get("ar", ""),
                "transliteration": basic.get("sound", ""),
                "category_short": basic.get("category", ""),
                "common_confusions": extended.get("common_confusions", []),
                "examples": extended.get("examples", []),
                "meaning_notes": extended.get("meaning_notes"),
                "has_extended": bool(extended),
            }

    def _format_category(self, code: str, short_category: str) -> str:
        """
        Build a human-friendly category string.

        Example: code='D21', short='body_parts' → 'Body Parts (Gardiner D)'
        """
        # Try to extract the Gardiner letter (A1 → A, Aa1 → Aa)
        letter = code[:2] if code.startswith("Aa") else code[0]
        gardiner_label = GARDINER_CATEGORIES.get(letter, "Unknown category")
        return f"{gardiner_label} (Gardiner {letter})"

    def get_by_code(self, code: str) -> Optional[SignInfoDetailed]:
        """
        Get detailed info for a single Gardiner sign.

        Args:
            code: Gardiner code (e.g., 'D21', 'N5')

        Returns:
            SignInfoDetailed if found, None otherwise.
        """
        sign = self._signs.get(code)
        if sign is None:
            return None

        return SignInfoDetailed(
            code=sign["code"],
            name_en=sign["name_en"],
            name_ar=sign["name_ar"],
            transliteration=sign["transliteration"],
            category=self._format_category(code, sign["category_short"]),
            common_confusions=sign["common_confusions"],
            image_url=None,  # populated later when we add sign images
            examples=sign["examples"],
            meaning_notes=sign["meaning_notes"],
        )

    def search(self, query: str, limit: int = 10) -> List[SignSearchResult]:
        """
        Search signs by code, name (en/ar), or transliteration.

        Scoring (0-1, higher = better match):
        - Exact code match → 1.0
        - Code prefix match → 0.9
        - Exact name match → 0.85
        - Name contains query → 0.6
        - Transliteration match → 0.5

        Args:
            query: Search string (case-insensitive)
            limit: Max results to return

        Returns:
            List of SignSearchResult, sorted by score descending.
        """
        if not query or not query.strip():
            return []

        q = query.strip().lower()
        scored: List[tuple[float, dict]] = []

        for code, sign in self._signs.items():
            score = self._score_match(q, code, sign)
            if score > 0:
                scored.append((score, sign))

        # Sort by score desc, then by code for stable ordering
        scored.sort(key=lambda t: (-t[0], t[1]["code"]))

        results = []
        for score, sign in scored[:limit]:
            results.append(
                SignSearchResult(
                    code=sign["code"],
                    name_en=sign["name_en"],
                    name_ar=sign["name_ar"],
                    transliteration=sign["transliteration"],
                    category=self._format_category(
                        sign["code"], sign["category_short"]
                    ),
                    score=round(score, 3),
                )
            )
        return results

    def _score_match(self, q: str, code: str, sign: dict) -> float:
        """Compute relevance score for a sign against a lowercase query."""
        code_lower = code.lower()
        name_en = sign["name_en"].lower()
        name_ar = sign["name_ar"]  # Arabic - keep original case
        translit = sign["transliteration"].lower()

        # Exact code match: highest score
        if q == code_lower:
            return 1.0
        # Code prefix
        if code_lower.startswith(q):
            return 0.9
        # Exact name match
        if q == name_en or q == name_ar:
            return 0.85
        # Exact transliteration match
        if q == translit:
            return 0.8
        # Name contains query
        if q in name_en or q in name_ar:
            return 0.6
        # Transliteration contains query
        if q in translit:
            return 0.5
        return 0.0

    def list_all(self) -> List[SignSearchResult]:
        """Return all signs as search results, sorted by code."""
        results = []
        for code in sorted(self._signs.keys()):
            sign = self._signs[code]
            results.append(
                SignSearchResult(
                    code=sign["code"],
                    name_en=sign["name_en"],
                    name_ar=sign["name_ar"],
                    transliteration=sign["transliteration"],
                    category=self._format_category(
                        code, sign["category_short"]
                    ),
                    score=1.0,
                )
            )
        return results

    @property
    def total_signs(self) -> int:
        """Total number of signs in the service."""
        return len(self._signs)