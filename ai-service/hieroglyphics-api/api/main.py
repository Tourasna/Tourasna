"""
Tourasna Hieroglyphics Translator API — main application entry point.

Run locally with:
    uvicorn api.main:app --reload

In production (AWS):
    uvicorn api.main:app --host 0.0.0.0 --port 8000 --workers 2

This file wires together:
  - Lifespan manager (loads ML models at startup)
  - CORS middleware (allows the Flutter/Node.js client to call us)
  - Request-logging middleware (logs every HTTP call)
  - Global exception handler (uniform JSON errors)
  - All routers mounted under /api
"""
from __future__ import annotations

import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.concurrency import run_in_threadpool
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
from starlette.exceptions import HTTPException as StarletteHTTPException

from api.config import settings
from api.routes import correction_router, health_router, signs_router, translate_router
from api.schemas import ErrorResponse
from api.services.model_loader import loader


# =============================================================================
# Lifespan — startup/shutdown hooks
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Load ML models once at startup; release resources at shutdown.

    Uvicorn runs this lifespan for each worker process, so with
    --workers=N the models load N times. That's fine on AWS where
    memory is abundant; locally we run a single worker.
    """
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    # Loading takes ~0.5s for all three models on CPU; running in a
    # threadpool keeps the event loop responsive during startup.
    await run_in_threadpool(loader.load_all)
    logger.info("API is ready to accept requests")

    yield  # <-- the app runs here

    logger.info("Shutting down API")
    # No explicit cleanup needed: torch tensors are garbage-collected
    # and the process exit releases everything.


# =============================================================================
# App creation
# =============================================================================

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=settings.app_description,
    lifespan=lifespan,
    # Put interactive docs at a clean URL
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)


# =============================================================================
# Middleware
# =============================================================================

# --- CORS -------------------------------------------------------------------
# For development and the graduation demo we allow any origin. In production
# on AWS this should be restricted to the actual Flutter app / Node backend
# domains — keep the env-based override below for that case.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # TODO(prod): tighten to known Flutter/Node origins
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Request logging --------------------------------------------------------
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """
    Log every HTTP request: method, path, status, duration.

    Skipped for noisy health polls to keep logs readable.
    """
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000

    # Don't flood the logs with health-check pings
    if request.url.path != "/api/health":
        logger.info(
            f"{request.method} {request.url.path} "
            f"-> {response.status_code} ({duration_ms:.0f} ms)"
        )
    return response


# =============================================================================
# Exception handlers
# =============================================================================

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """
    Wrap any HTTPException in our standard ErrorResponse shape so the
    Node.js/Flutter client has a single error format to handle.
    """
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=_status_code_to_error_type(exc.status_code),
            message=str(exc.detail),
        ).model_dump(),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
):
    """
    Pydantic validation failures return 422 with the validation details
    in the `details` field.
    """
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=ErrorResponse(
            error="validation_error",
            message="Request body or parameters failed validation.",
            details={"errors": exc.errors()},
        ).model_dump(),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """
    Catch-all for unexpected exceptions. Log them and return a sanitized
    500 error — never leak stack traces to the client.
    """
    logger.exception(
        f"Unhandled error in {request.method} {request.url.path}: {exc}"
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(
            error="internal_error",
            message="An internal server error occurred.",
        ).model_dump(),
    )


def _status_code_to_error_type(code: int) -> str:
    """Map common HTTP status codes to machine-readable error types."""
    mapping = {
        400: "bad_request",
        401: "unauthorized",
        403: "forbidden",
        404: "not_found",
        413: "payload_too_large",
        415: "unsupported_media_type",
        422: "validation_error",
        429: "rate_limited",
        500: "internal_error",
        503: "service_unavailable",
    }
    return mapping.get(code, "error")


# =============================================================================
# Routers
# =============================================================================

# All feature endpoints live under /api so that one day we can serve a
# static UI at /  without colliding with the JSON API.
app.include_router(correction_router, prefix="/api")
app.include_router(health_router, prefix="/api")
app.include_router(signs_router, prefix="/api")
app.include_router(translate_router, prefix="/api")


# =============================================================================
# Root redirect — convenience for humans visiting the bare URL
# =============================================================================

@app.get("/", include_in_schema=False)
async def root():
    """
    Minimal landing response with links into the API.
    Hidden from the OpenAPI schema since it's informational only.
    """
    return {
        "message": f"{settings.app_name} v{settings.app_version}",
        "docs": "/docs",
        "health": "/api/health",
        "signs": "/api/signs",
    }