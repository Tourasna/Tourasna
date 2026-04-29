"""
Schemas for the translation pipeline output and API endpoints.

The translation result combines three layers:
  1. Database lookup (known royal names, formulas, deities)
  2. Transformer sequence-to-sequence model
  3. Individual sign meanings (fallback)

These schemas also define the request/response contracts for
all /api/translate*, /api/signs, and /api/health endpoints.
"""
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field

from api.schemas.common import ImageSize, ReadingDirection
from api.schemas.detection import Detection


class TranslationMethod(str, Enum):
    """Which layer of the hybrid translator produced the translation."""
    DATABASE_EXACT = "database_exact"     # Layer 1: Matched a full phrase in translations_db
    LLM_TRANSLATION = "llm_translation"   # Layer 2: Groq + Llama 3.3 70B (NEW)
    TRANSFORMER = "transformer"           # Layer 3: Seq2Seq transformer output
    SIGN_MEANINGS_ONLY = "sign_meanings"  # Layer 4: Fallback - concatenated sign meanings
    EMPTY = "empty"                       # No glyphs detected in the image


class SignDetail(BaseModel):
    """
    Per-sign linguistic information, used as a tooltip/detail in the app.
    Sourced from the `sign_meanings` section of translations_db.json.
    """
    code: str = Field(..., description="Gardiner code")
    meaning_en: Optional[str] = Field(None, description="Meaning in English")
    meaning_ar: Optional[str] = Field(None, description="Meaning in Arabic")
    sound: Optional[str] = Field(None, description="Phonetic transliteration")
    category: Optional[str] = Field(
        None,
        description="Gardiner category (e.g., 'sun/time', 'birds', 'human')",
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "code": "N5",
                "meaning_en": "sun disk",
                "meaning_ar": "قرص الشمس",
                "sound": "Ra",
                "category": "sky/earth",
            }
        }
    }


class TranslationResult(BaseModel):
    """
    The linguistic output of the translation pipeline.

    Returned inside /api/translate and /api/translate-codes responses.
    Contains translations in both target languages plus optional context.
    """
    method: TranslationMethod = Field(
        ...,
        description="Which layer produced this translation",
    )

    translation_en: str = Field(..., description="English translation")
    translation_ar: str = Field(..., description="Arabic translation")

    transliteration: Optional[str] = Field(
        None,
        description="Phonetic reading (e.g., 'Ra-mes-su' for Ramesses)",
    )

    context_en: Optional[str] = Field(
        None,
        description=(
            "Historical/cultural context in English. "
            "Available only for database_exact matches."
        ),
    )
    context_ar: Optional[str] = Field(
        None,
        description=(
            "Historical/cultural context in Arabic. "
            "Available only for database_exact matches."
        ),
    )

    sign_details: List[SignDetail] = Field(
        default_factory=list,
        description=(
            "Per-sign breakdown for educational tooltips. "
            "Populated when individual sign meanings are known."
        ),
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "method": "database_exact",
                "translation_en": "Ramesses (Born of Ra)",
                "translation_ar": "رمسيس (ابن رع)",
                "transliteration": "Ra-mes-su",
                "context_en": (
                    "Birth name of Ramesses II, one of ancient Egypt's "
                    "most powerful pharaohs."
                ),
                "context_ar": "اسم الميلاد لرمسيس الثاني، أحد أقوى فراعنة مصر القديمة.",
                "sign_details": [
                    {
                        "code": "N5",
                        "meaning_en": "sun disk",
                        "meaning_ar": "قرص الشمس",
                        "sound": "Ra",
                        "category": "sky/earth",
                    }
                ],
            }
        }
    }


# ===== Request schemas =====

class TranslateCodesRequest(BaseModel):
    """
    Body for POST /api/translate-codes.

    Used when the tourist has corrected the detected sequence in the app
    and wants a fresh translation without re-uploading and re-detecting
    the image.
    """
    gardiner_codes: List[str] = Field(
        ...,
        
        description="Ordered list of Gardiner codes to translate",
    )
    reading_direction: ReadingDirection = Field(
        default=ReadingDirection.RTL,
        description=(
            "Reading direction. The codes list is already in reading order; "
            "this is included for context/logging."
        ),
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "gardiner_codes": ["N5", "S29", "S29", "M23", "X1"],
                "reading_direction": "rtl",
            }
        }
    }
class TranslateCorrectedRequest(BaseModel):
    """
    Request body for translating a user-corrected sequence.

    This is used after the user reviews the AI's detection and makes
    corrections (changing a glyph, removing a wrong one, or confirming
    the reading direction).
    """

    corrected_sequence: List[str] = Field(
        ...,
        description="User-verified Gardiner codes in reading order",
    )

    reading_direction: ReadingDirection = Field(
        default=ReadingDirection.RTL,
        description="Reading direction confirmed by the user",
    )

    original_detection_ids: Optional[List[str]] = Field(
        default=None,
        description="Optional: IDs of original detections for tracking",
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "corrected_sequence": ["N5", "S29", "S29", "M23", "X1"],
                "reading_direction": "rtl",
            }
        }
    }


# ===== Response schemas =====

class TranslateResponse(BaseModel):
    """
    Response from POST /api/translate.

    Contains everything the frontend needs to:
      1. Overlay detection boxes on the image
      2. Display the translation
      3. Let the user correct the sequence and re-translate
    """
    image_size: ImageSize
    reading_direction: ReadingDirection

    total_detections: int = Field(..., ge=0)
    rows: int = Field(..., ge=0, description="Number of text rows detected")
    quadrats: int = Field(
        ...,
        ge=0,
        description="Number of quadrats (glyph groups)",
    )

    detections: List[Detection] = Field(
        default_factory=list,
        description="All detected glyphs, ordered by reading sequence",
    )
    gardiner_sequence: List[str] = Field(
        default_factory=list,
        description="Flat list of Gardiner codes in reading order",
    )
    translation: TranslationResult


class TranslateCodesResponse(BaseModel):
    """
    Response from POST /api/translate-codes.

    Simpler than TranslateResponse — no image or detection data,
    just the translation for the corrected codes.
    """
    gardiner_codes: List[str]
    reading_direction: ReadingDirection
    translation: TranslationResult


class SignInfo(BaseModel):
    """Single entry in the GET /api/signs response."""
    gardiner_code: str
    meaning_en: Optional[str] = None
    meaning_ar: Optional[str] = None
    sound: Optional[str] = None
    category: Optional[str] = None


class SignsListResponse(BaseModel):
    """Response from GET /api/signs."""
    total: int = Field(..., ge=0)
    signs: List[SignInfo]


class HealthResponse(BaseModel):
    """Response from GET /api/health."""
    status: str = Field(..., description="'healthy' or 'unhealthy'")
    version: str
    models_loaded: bool = Field(
        ...,
        description="True if all ML models are loaded and ready to serve requests",
    )
    device: str = Field(..., description="'cuda' or 'cpu'")


# ===== Error schemas =====

class ErrorResponse(BaseModel):
    """
    Standard error response format used by all endpoints.

    Frontend handlers can rely on this consistent shape
    to display error messages to the user.
    """
    error: str = Field(
        ...,
        description="Machine-readable error type (e.g., 'invalid_image')",
    )
    message: str = Field(..., description="Human-readable error message")
    details: Optional[dict] = Field(
        None,
        description="Optional extra context (e.g., validation details)",
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "error": "invalid_image",
                "message": "Uploaded file is not a valid image.",
                "details": {"received_type": "application/pdf"},
            }
        }
    }