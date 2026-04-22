"""
Tourasna Hieroglyphics Translator API

Main FastAPI application entry point.
Run with: uvicorn api.main:app --reload
"""
from fastapi import FastAPI
from api.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=settings.app_description,
)


@app.get("/")
async def root():
    """Welcome endpoint - confirms the API is running."""
    return {
        "message": "Tourasna Hieroglyphics Translator API",
        "version": settings.app_version,
        "docs": "/docs",
    }