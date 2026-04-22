"""
Public exports for the schemas package.

Import from here in routes and services instead of the submodules:
    from api.schemas import Detection, TranslateResponse

This gives us a single import point and lets us refactor internals
without breaking callers.
"""
from api.schemas.common import (
    BoundingBox,
    ImageSize,
    ReadingDirection,
)
from api.schemas.detection import (
    Alternative,
    Detection,
)
from api.schemas.translation import (
    ErrorResponse,
    HealthResponse,
    SignDetail,
    SignInfo,
    SignsListResponse,
    TranslateCodesRequest,
    TranslateCodesResponse,
    TranslateResponse,
    TranslationMethod,
    TranslationResult,
)

__all__ = [
    # Common
    "BoundingBox",
    "ImageSize",
    "ReadingDirection",
    # Detection
    "Alternative",
    "Detection",
    # Translation
    "ErrorResponse",
    "HealthResponse",
    "SignDetail",
    "SignInfo",
    "SignsListResponse",
    "TranslateCodesRequest",
    "TranslateCodesResponse",
    "TranslateResponse",
    "TranslationMethod",
    "TranslationResult",
]