"""
Common Pydantic schemas shared across the API.

These are the building blocks used by detection and translation schemas.
Defining them here avoids circular imports and keeps the data model clean.
"""
from enum import Enum
from pydantic import BaseModel, Field


class ReadingDirection(str, Enum):
    """
    Direction in which hieroglyphs should be read.

    Most inscriptions are RTL (right-to-left) but some are LTR.
    The tourist can override the default from the Flutter app.

    Note: Extending to vertical columns (top-to-bottom) is a future enhancement,
    not in scope for the graduation project.
    """
    RTL = "rtl"
    LTR = "ltr"


class BoundingBox(BaseModel):
    """
    Axis-aligned bounding box in pixel coordinates.

    Convention: Origin (0, 0) is top-left of the image (standard image convention).
    Invariants: x1 < x2 and y1 < y2.
    """
    x1: float = Field(..., ge=0, description="Left edge (pixels)")
    y1: float = Field(..., ge=0, description="Top edge (pixels)")
    x2: float = Field(..., ge=0, description="Right edge (pixels)")
    y2: float = Field(..., ge=0, description="Bottom edge (pixels)")

    @property
    def width(self) -> float:
        """Box width in pixels."""
        return self.x2 - self.x1

    @property
    def height(self) -> float:
        """Box height in pixels."""
        return self.y2 - self.y1

    @property
    def center_x(self) -> float:
        """Horizontal center of the box."""
        return (self.x1 + self.x2) / 2

    @property
    def center_y(self) -> float:
        """Vertical center of the box."""
        return (self.y1 + self.y2) / 2

    model_config = {
        "json_schema_extra": {
            "example": {"x1": 100.0, "y1": 50.0, "x2": 180.0, "y2": 130.0}
        }
    }


class ImageSize(BaseModel):
    """Dimensions of the processed image in pixels."""
    width: int = Field(..., gt=0, description="Image width in pixels")
    height: int = Field(..., gt=0, description="Image height in pixels")

    model_config = {
        "json_schema_extra": {
            "example": {"width": 1024, "height": 768}
        }
    }