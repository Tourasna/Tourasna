"""
Schemas for glyph detection results.

A Detection represents a single glyph identified in the image,
including its classification (Gardiner code), confidence,
bounding box, and position in the reading sequence.
"""
from typing import List
from pydantic import BaseModel, Field

from api.schemas.common import BoundingBox


class Alternative(BaseModel):
    """
    An alternative classification for an ambiguous glyph.

    Returned when the top prediction's confidence is below the ambiguity
    threshold, so the tourist can pick the correct one in the Flutter app.
    """
    gardiner_code: str = Field(
        ...,
        description="Gardiner sign list code (e.g., 'N5', 'S29')",
    )
    confidence: float = Field(
        ...,
        ge=0,
        le=1,
        description="Model confidence for this alternative, range [0, 1]",
    )

    model_config = {
        "json_schema_extra": {
            "example": {"gardiner_code": "N5", "confidence": 0.73}
        }
    }


class Detection(BaseModel):
    """
    A single detected hieroglyph.

    The Flutter frontend uses this to:
      1. Draw a bounding-box overlay on the image
      2. Show the tourist the detected Gardiner code
      3. Offer alternatives if the detection is ambiguous
      4. Let the tourist remove false positives
    """
    # Identity
    id: int = Field(..., ge=1, description="Sequential ID (1-indexed)")

    # Classification
    gardiner_code: str = Field(
        ...,
        description="Top-predicted Gardiner code",
    )
    confidence: float = Field(
        ...,
        ge=0,
        le=1,
        description="Confidence of the top prediction",
    )

    # Spatial info
    bbox: BoundingBox

    # Reading-order info (filled in by the sorter service)
    row: int = Field(
        ...,
        ge=1,
        description="Row number, 1-indexed (top to bottom in the image)",
    )
    quadrat_id: int = Field(
        ...,
        ge=1,
        description="Quadrat group ID within the row (1-indexed)",
    )
    position_in_quadrat: int = Field(
        ...,
        ge=1,
        description="Position within the quadrat (1-indexed, top to bottom)",
    )

    # Ambiguity info
    is_ambiguous: bool = Field(
        ...,
        description=(
            "True if the top confidence is below the ambiguity threshold. "
            "The frontend should highlight these for user review."
        ),
    )
    alternatives: List[Alternative] = Field(
        default_factory=list,
        description=(
            "Top-K alternative classifications, sorted by confidence descending. "
            "Empty when is_ambiguous is False."
        ),
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "id": 1,
                "gardiner_code": "N5",
                "confidence": 0.92,
                "bbox": {"x1": 100.0, "y1": 50.0, "x2": 180.0, "y2": 130.0},
                "row": 1,
                "quadrat_id": 1,
                "position_in_quadrat": 1,
                "is_ambiguous": False,
                "alternatives": [],
            }
        }
    }