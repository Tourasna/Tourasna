"""
Pytest fixtures shared across all test modules.

The TestClient fixture has session scope so the ML models load once per
test run, not once per test. Without this, every test would pay the
~0.5s model-load cost.
"""
from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from api.main import app


TESTS_DIR = Path(__file__).parent
FIXTURES_DIR = TESTS_DIR / "fixtures"


@pytest.fixture(scope="session")
def client():
    """
    FastAPI TestClient that runs the app's lifespan (loads models once).

    Using the context-manager form ensures startup/shutdown hooks fire.
    """
    with TestClient(app) as c:
        yield c


@pytest.fixture
def ramesses_image_bytes() -> bytes:
    """Return the bytes of the RamsesII cartouche test image."""
    path = FIXTURES_DIR / "RamsesII_cartouche.jpg"
    if not path.exists():
        pytest.skip(
            f"Test fixture missing: {path}. "
            "Copy RamsesII_cartouche.jpg to tests/fixtures/ to enable image tests."
        )
    return path.read_bytes()


@pytest.fixture
def ramesses_codes() -> list[str]:
    """The known Gardiner sequence for Ramesses II birth name."""
    return ["N5", "S29", "S29", "M23", "X1"]