"""
Signs listing endpoint.

Returns all known Gardiner sign meanings from translations_db.
The frontend uses this to:
  - Show a reference guide to the user
  - Let users browse the alphabet
  - Populate autocomplete when editing detected codes
"""
from fastapi import APIRouter, HTTPException

from api.schemas import SignInfo, SignsListResponse
from api.services.model_loader import loader


router = APIRouter(tags=["Reference"])


@router.get(
    "/signs",
    response_model=SignsListResponse,
    summary="List all known Gardiner signs",
    description=(
        "Returns all Gardiner codes for which we have a stored meaning "
        "(currently 64 common signs). Each entry includes English and "
        "Arabic meaning, phonetic transliteration, and a category."
    ),
)
async def list_signs() -> SignsListResponse:
    """Return every sign in the translations_db sign_meanings section."""
    if not loader.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Service is still starting; try again in a moment.",
        )

    signs = [
        SignInfo(
            gardiner_code=code,
            meaning_en=data.get("en"),
            meaning_ar=data.get("ar"),
            sound=data.get("sound"),
            category=data.get("category"),
        )
        for code, data in sorted(loader.sign_meanings.items())
    ]

    return SignsListResponse(total=len(signs), signs=signs)