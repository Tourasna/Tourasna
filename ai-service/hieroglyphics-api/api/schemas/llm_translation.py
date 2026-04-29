"""
Schemas for LLM-based translation (Layer 2: Groq + Llama 3.3 70B).

These schemas define the structure of LLM responses.
The strict format ensures consistent, parseable output.
"""
from __future__ import annotations

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class LLMConfidence(str, Enum):
    """Confidence level reported by the LLM about its translation."""
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class LLMTranslationType(str, Enum):
    """Type of inscription identified by the LLM."""
    ROYAL_NAME = "royal_name"
    THRONE_NAME = "throne_name"
    DEITY = "deity"
    OFFERING_FORMULA = "offering_formula"
    EPITHET = "epithet"
    COMMON_PHRASE = "common_phrase"
    TITLE = "title"
    PLACE_NAME = "place_name"
    WORD = "word"
    UNKNOWN = "unknown"


class LLMTranslationResult(BaseModel):
    """
    Structured response from the LLM translator.

    The LLM is prompted to return a strict JSON object matching this schema.
    Pydantic validates the response, catching malformed LLM output.
    """

    translation_en: str = Field(
        ...,
        description="Complete grammatical English translation",
        max_length=500,
    )
    translation_ar: str = Field(
        ...,
        description="Complete Arabic translation",
        max_length=500,
    )
    transliteration: str = Field(
        default="",
        description="Standard Egyptological transliteration (e.g., 'Ra-mes-sw')",
        max_length=200,
    )
    confidence: LLMConfidence = Field(
        ...,
        description="LLM's confidence in this translation",
    )
    type: LLMTranslationType = Field(
        ...,
        description="Type of inscription identified",
    )
    explanation_en: str = Field(
        default="",
        description="Brief explanation of the inscription's meaning and context",
        max_length=1000,
    )
    explanation_ar: str = Field(
        default="",
        description="Brief Arabic explanation",
        max_length=1000,
    )
    is_complete_phrase: bool = Field(
        default=False,
        description="Whether the input forms a complete grammatical phrase",
    )
    warning: str = Field(
        default="",
        description="Any caveats or notes about uncertainty",
        max_length=500,
    )