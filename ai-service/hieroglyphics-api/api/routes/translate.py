"""
Translation endpoints — the heart of the API.

POST /translate        : full pipeline (image upload -> translation)
POST /translate-codes  : translate a corrected sequence of Gardiner codes

These endpoints compose the three services built in previous steps:
  DetectorService -> SorterService -> TranslatorService
"""
from __future__ import annotations

from io import BytesIO
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from loguru import logger
from PIL import Image, UnidentifiedImageError

from api.config import settings
from api.schemas import (
    ImageSize,
    ReadingDirection,
    TranslateCodesRequest,
    TranslateCodesResponse,
    TranslateResponse,
)
from api.services.detector_service import DetectorService
from api.services.model_loader import loader
from api.services.sorter_service import SorterService
from api.services.translator_service import TranslatorService


router = APIRouter(tags=["Translation"])


# =============================================================================
# Dependency providers
# =============================================================================
# We expose these as dependencies so routes declare what they need, and
# tests can substitute mocks by overriding them with app.dependency_overrides.

def get_detector() -> DetectorService:
    """Provide a DetectorService instance bound to the global loader."""
    if not loader.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Service is still starting; try again in a moment.",
        )
    return DetectorService(loader)


def get_sorter() -> SorterService:
    """Provide a SorterService instance (stateless)."""
    return SorterService()


def get_translator() -> TranslatorService:
    """Provide a TranslatorService instance bound to the global loader."""
    if not loader.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Service is still starting; try again in a moment.",
        )
    return TranslatorService(loader)


# =============================================================================
# POST /translate — full pipeline (image -> translation)
# =============================================================================

@router.post(
    "/translate",
    response_model=TranslateResponse,
    summary="Detect and translate hieroglyphs from an image",
    description=(
        "Upload a photo of a hieroglyphic inscription. The API will:\n"
        "1. Detect all glyphs (YOLOv8, 767 Gardiner classes)\n"
        "2. Sort them into reading order (quadrat-based, 2D-aware)\n"
        "3. Translate using the hybrid 3-layer pipeline "
        "(database → transformer → sign meanings)"
    ),
)
async def translate(
    image: Annotated[UploadFile, File(description="Image file (JPEG/PNG/WEBP)")],
    reading_direction: Annotated[
        ReadingDirection,
        Form(description="Reading direction (default: rtl)"),
    ] = ReadingDirection.RTL,
    detector: DetectorService = Depends(get_detector),
    sorter: SorterService = Depends(get_sorter),
    translator: TranslatorService = Depends(get_translator),
) -> TranslateResponse:
    """
    Full pipeline: image -> detect -> sort -> translate.

    Heavy CPU work (YOLO + Transformer) is pushed to a thread pool so the
    event loop stays responsive for other concurrent requests.
    """
    # ---- 1. Validate the upload -------------------------------------------
    _validate_image_upload(image)

    raw_bytes = await image.read()
    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    max_bytes = settings.max_image_size_mb * 1024 * 1024
    if len(raw_bytes) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=(
                f"Image too large ({len(raw_bytes) // 1024} KB). "
                f"Max allowed is {settings.max_image_size_mb} MB."
            ),
        )

    # ---- 2. Decode image --------------------------------------------------
    try:
        pil_image = Image.open(BytesIO(raw_bytes))
        pil_image.load()  # force decode now to catch corrupt files early
    except (UnidentifiedImageError, OSError) as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Could not decode image: {exc}",
        ) from exc

    if pil_image.mode != "RGB":
        pil_image = pil_image.convert("RGB")
    orig_w, orig_h = pil_image.size

    logger.info(
        f"/translate called: image={orig_w}x{orig_h} "
        f"({len(raw_bytes) // 1024} KB), direction={reading_direction.value}"
    )

    # ---- 3. Run the pipeline in a thread pool -----------------------------
    # These are CPU-bound; keeping them off the event loop prevents blocking.
    raw_detections = await run_in_threadpool(detector.detect, pil_image)
    sorted_detections, num_rows, num_quadrats = await run_in_threadpool(
        sorter.sort, raw_detections, reading_direction
    )
    gardiner_sequence = [d.gardiner_code for d in sorted_detections]
    translation = await run_in_threadpool(translator.translate, gardiner_sequence)

    # ---- 4. Build the response --------------------------------------------
    return TranslateResponse(
        image_size=ImageSize(width=orig_w, height=orig_h),
        reading_direction=reading_direction,
        total_detections=len(sorted_detections),
        rows=num_rows,
        quadrats=num_quadrats,
        detections=sorted_detections,
        gardiner_sequence=gardiner_sequence,
        translation=translation,
    )


# =============================================================================
# POST /translate-codes — translate a user-corrected sequence
# =============================================================================

@router.post(
    "/translate-codes",
    response_model=TranslateCodesResponse,
    summary="Translate a sequence of Gardiner codes",
    description=(
        "Use this after the user has reviewed and corrected the detected "
        "sequence in the app. Skips the image pipeline and just runs the "
        "3-layer translator on the codes as given."
    ),
)
async def translate_codes(
    request: TranslateCodesRequest,
    translator: TranslatorService = Depends(get_translator),
) -> TranslateCodesResponse:
    """
    Run the hybrid translator on a given Gardiner-code sequence.

    The reading_direction is accepted for context/logging but the codes
    are assumed to already be in reading order.
    """
    codes = request.gardiner_codes
    logger.info(
        f"/translate-codes called: {len(codes)} codes, "
        f"direction={request.reading_direction.value}"
    )

    translation = await run_in_threadpool(translator.translate, codes)

    return TranslateCodesResponse(
        gardiner_codes=codes,
        reading_direction=request.reading_direction,
        translation=translation,
    )


# =============================================================================
# Helpers
# =============================================================================

def _validate_image_upload(image: UploadFile) -> None:
    """
    Pre-read validation of the uploaded file. Keeps failure cases cheap
    (reject before reading the whole file into memory).
    """
    content_type = (image.content_type or "").lower()
    if content_type not in settings.allowed_image_types:
        raise HTTPException(
            status_code=415,
            detail=(
                f"Unsupported image type: {content_type!r}. "
                f"Allowed: {', '.join(settings.allowed_image_types)}."
            ),
        )