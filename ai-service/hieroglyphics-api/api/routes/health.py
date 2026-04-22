"""
Health check endpoint.

Used by:
  - The Node.js team to verify the Python API is up
  - Load balancers / container orchestrators for readiness probes
  - Monitoring / alerting systems
"""
from fastapi import APIRouter

from api.config import settings
from api.schemas import HealthResponse
from api.services.model_loader import loader


router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Health check",
    description=(
        "Returns the API status and whether all ML models are loaded "
        "and ready to serve requests. Use this for readiness probes."
    ),
)
async def health() -> HealthResponse:
    """
    Returns a snapshot of the service status.
    Returns 200 OK even if unhealthy — the body tells you the state.
    (Some orchestrators prefer this; readiness is signaled via `status`.)
    """
    return HealthResponse(
        status="healthy" if loader.is_loaded else "starting",
        version=settings.app_version,
        models_loaded=loader.is_loaded,
        device=str(loader.device),
    )