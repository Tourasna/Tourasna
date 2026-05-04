"""
Correction support endpoints — interactive Human-in-the-Loop UI.

These endpoints power the sign-correction UI in the Tourasna app:
- When a tourist taps a detected glyph, fetch detailed info about it
- When a tourist manually searches for a sign, find matches by name/code

This is part of Improvement #1: Interactive Correction. Rather than
chasing impossible AI accuracy on tourist photos, we let users verify
and correct detections — the AI suggests, the human confirms.
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from loguru import logger

from api.schemas import (
    SignInfoDetailed,
    SignSearchResponse,
)
from api.services.model_loader import loader
from api.services.sign_info_service import SignInfoService


router = APIRouter(tags=["Correction"])


# =============================================================================
# Dependency provider
# =============================================================================

def get_sign_info_service() -> SignInfoService:
    """
    Provide the SignInfoService instance bound to the global loader.

    The service is loaded once at startup (in ModelLoader.load_all)
    and reused for every request — no per-request loading cost.
    """
    if not loader.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Service is still starting; try again in a moment.",
        )
    if loader.sign_info_service is None:
        # Defensive — should never happen if load_all() succeeded
        raise HTTPException(
            status_code=503,
            detail="Sign info service is not available.",
        )
    return loader.sign_info_service


# =============================================================================
# GET /sign/{code}/info — detailed info for a single sign
# =============================================================================

@router.get(
    "/sign/{code}/info",
    response_model=SignInfoDetailed,
    summary="Get detailed info for a single Gardiner sign",
    description=(
        "Returns full information about a Gardiner sign including its "
        "English/Arabic names, transliteration, category, common visual "
        "confusions (other signs that look similar), and usage examples.\n\n"
        "Used by the correction UI when a user taps on a detected glyph "
        "to learn more about it."
    ),
    responses={
        404: {"description": "Sign not found in our knowledge base"},
    },
)
async def get_sign_info(
    code: str,
    service: SignInfoService = Depends(get_sign_info_service),
) -> SignInfoDetailed:
    """Return detailed info for a single Gardiner sign."""
    info = service.get_by_code(code)
    if info is None:
        raise HTTPException(
            status_code=404,
            detail=f"Sign '{code}' not found in our knowledge base.",
        )
    return info


# =============================================================================
# GET /signs/search — search by code/name/transliteration
# =============================================================================

@router.get(
    "/signs/search",
    response_model=SignSearchResponse,
    summary="Search signs by code, name, or transliteration",
    description=(
        "Search across all known signs. Matches by:\n"
        "- Gardiner code (e.g., 'D2' matches D21, D22, ...)\n"
        "- English name (e.g., 'mouth' matches D21)\n"
        "- Arabic name\n"
        "- Phonetic transliteration (e.g., 'ra' matches N5)\n\n"
        "Used by the correction UI when a user wants to manually pick "
        "a sign after deleting a wrong AI detection."
    ),
)
async def search_signs(
    q: str = Query(
        ...,
        min_length=1,
        max_length=50,
        description="Search query (case-insensitive)",
        examples=["mouth", "D2", "ra"],
    ),
    limit: int = Query(
        default=10,
        ge=1,
        le=50,
        description="Maximum number of results (default 10, max 50)",
    ),
    service: SignInfoService = Depends(get_sign_info_service),
) -> SignSearchResponse:
    """Search signs by query string."""
    logger.info(f"/signs/search called: q={q!r}, limit={limit}")

    results = service.search(q, limit=limit)
    return SignSearchResponse(
        query=q,
        results=results,
        total=len(results),
    )