"""
Schemas for the interactive correction system.

These schemas support the Human-in-the-Loop workflow where users can:
1. View detailed information about any Gardiner sign
2. Search for signs by name, transliteration, or meaning
3. Get common confusion patterns to inform corrections
"""
from typing import List, Optional

from pydantic import BaseModel, Field


# ============================================================
# === SIGN INFORMATION ===
# ============================================================

class SignInfoDetailed(BaseModel):
    """Detailed information about a single Gardiner sign."""

    code: str = Field(
        ...,
        description="Gardiner code (e.g., 'D21', 'N5', 'S29')",
        examples=["D21", "N5"],
    )

    name_en: str = Field(
        ...,
        description="English name of the sign",
        examples=["mouth", "sun"],
    )

    name_ar: str = Field(
        ...,
        description="Arabic name of the sign",
        examples=["fam", "shams"],
    )

    transliteration: str = Field(
        ...,
        description="Phonetic transliteration",
        examples=["r", "ra"],
    )

    category: str = Field(
        ...,
        description="Gardiner category description",
        examples=["Body Parts (D)", "Sky and Earth (N)"],
    )

    common_confusions: List[str] = Field(
        default_factory=list,
        description="Gardiner codes that look visually similar to this one",
        examples=[["D4", "D40", "F12"]],
    )

    image_url: Optional[str] = Field(
        default=None,
        description="URL to a reference image/SVG of this sign",
    )

    examples: List[str] = Field(
        default_factory=list,
        description="Usage examples in Egyptian inscriptions",
    )

    meaning_notes: Optional[str] = Field(
        default=None,
        description="Brief note about meaning or usage context",
    )


# ============================================================
# === SIGN SEARCH ===
# ============================================================

class SignSearchResult(BaseModel):
    """A single search result for a sign."""

    code: str = Field(..., description="Gardiner code")
    name_en: str = Field(..., description="English name")
    name_ar: str = Field(..., description="Arabic name")
    transliteration: str = Field(..., description="Phonetic transliteration")
    category: str = Field(..., description="Gardiner category")

    score: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Relevance score (0-1, higher is better match)",
    )


class SignSearchResponse(BaseModel):
    """Response for the sign search endpoint."""

    query: str = Field(..., description="The search query")
    results: List[SignSearchResult] = Field(
        default_factory=list,
        description="Matching signs, ordered by relevance",
    )
    total: int = Field(..., ge=0, description="Total number of matches")


# ============================================================
# === GENERIC ERROR FOR CORRECTION ENDPOINTS ===
# ============================================================

class SignNotFoundError(BaseModel):
    """Returned when a Gardiner code is not in our knowledge base."""

    code: str = Field(..., description="The unknown code")
    suggestion: Optional[str] = Field(
        default=None,
        description="Suggested similar code if any",
    )
    message: str = Field(
        default="Sign not found in our knowledge base.",
        description="Human-readable error message",
    )