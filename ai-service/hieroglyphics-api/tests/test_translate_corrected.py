"""
Tests for POST /api/translate-corrected.

This endpoint trusts user-verified Gardiner sequences (Human-in-the-Loop).
It's structurally similar to /translate-codes but uses a different request
schema and exists for analytics/clarity.
"""


def test_translate_corrected_ramesses_cartouche(client):
    """User-corrected Ramesses sequence returns the database hit."""
    response = client.post(
        "/api/translate-corrected",
        json={
            "corrected_sequence": ["N5", "S29", "S29", "M23", "X1"],
            "reading_direction": "rtl",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["translation"]["method"] == "database_exact"
    assert "Ramesses" in data["translation"]["translation_en"]


def test_translate_corrected_empty_sequence_returns_empty_method(client):
    """Empty sequence is allowed and returns method=empty."""
    response = client.post(
        "/api/translate-corrected",
        json={
            "corrected_sequence": [],
            "reading_direction": "rtl",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["translation"]["method"] == "empty"


def test_translate_corrected_supports_ttb_reading_direction(client):
    """TTB (top-to-bottom) is a valid reading direction for vertical columns."""
    response = client.post(
        "/api/translate-corrected",
        json={
            "corrected_sequence": ["N5", "S29", "S29", "M23", "X1"],
            "reading_direction": "ttb",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["reading_direction"] == "ttb"


def test_translate_corrected_missing_field_returns_422(client):
    """Missing corrected_sequence field returns 422."""
    response = client.post(
        "/api/translate-corrected",
        json={"reading_direction": "rtl"},
    )
    assert response.status_code == 422


def test_translate_corrected_invalid_direction_returns_422(client):
    """Invalid reading direction returns 422."""
    response = client.post(
        "/api/translate-corrected",
        json={
            "corrected_sequence": ["N5"],
            "reading_direction": "diagonal",  # not a valid direction
        },
    )
    assert response.status_code == 422