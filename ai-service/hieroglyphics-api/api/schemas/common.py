# File: api/schemas/common.py
# CHANGE: Add TTB option to ReadingDirection enum

"""
Common schemas shared across the API.
"""
from enum import Enum

from pydantic import BaseModel, Field


class ReadingDirection(str, Enum):
    """
    Reading direction of the hieroglyph inscription.
    
    - RTL: right-to-left (most common in Egyptian inscriptions)
    - LTR: left-to-right (less common, used in some contexts)
    - TTB: top-to-bottom (vertical columns, common in tomb walls and stelae)
    """
    RTL = "rtl"
    LTR = "ltr"
    TTB = "ttb"  # NEW: Top-to-bottom for vertical columns


class BoundingBox(BaseModel):
    """Bounding box for a detected glyph in image coordinates."""
    
    x1: float = Field(..., description="Left edge in pixels")
    y1: float = Field(..., description="Top edge in pixels")
    x2: float = Field(..., description="Right edge in pixels")
    y2: float = Field(..., description="Bottom edge in pixels")
    
    @property
    def width(self) -> float:
        return self.x2 - self.x1
    
    @property
    def height(self) -> float:
        return self.y2 - self.y1
    
    @property
    def center_x(self) -> float:
        return (self.x1 + self.x2) / 2
    
    @property
    def center_y(self) -> float:
        return (self.y1 + self.y2) / 2


class ImageSize(BaseModel):
    """Image dimensions."""
    width: int = Field(..., gt=0, description="Image width in pixels")
    height: int = Field(..., gt=0, description="Image height in pixels")