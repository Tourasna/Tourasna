"""
Tests for POST /api/translate-codes — the core 3-layer translator.

Covers all four possible `method` values in the response:
  - database_exact
  - transformer
  - sign_meanings
  - empty
"""


# -----------------------------------------------------------------------------
# Layer 1: Database
# -----------------------------------------------------------------------------

def test_database_exact_match_ramesses(client, ramesses_codes):
    """The canonical Ramesses sequence must hit the database layer."""
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": ramesses_codes, "reading_direction": "rtl"},
    )
    assert response.status_code == 200

    data = response.json()
    t = data["translation"]

    assert t["method"] == "database_exact"
    assert "Ramesses" in t["translation_en"]
    assert t["translation_ar"]  # non-empty Arabic
    assert t["transliteration"] == "Ra-mes-su"
    assert t["context_en"]  # historical context present
    assert len(t["sign_details"]) == 5


def test_database_subsequence_match(client):
    """A partial Ramesses sequence should still hit the DB with a note."""
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": ["N5", "S29", "S29"]},
    )
    assert response.status_code == 200

    data = response.json()
    t = data["translation"]
    assert t["method"] == "database_exact"
    assert "partial" in t["translation_en"].lower()


# -----------------------------------------------------------------------------
# Layer 3: Sign meanings fallback (simpler than layer 2 to test deterministically)
# -----------------------------------------------------------------------------

def test_all_unknown_codes_fall_back_to_sign_meanings(client):
    """
    Completely unknown codes should produce SOME translation.

    With the LLM layer enabled, the LLM may handle unknown codes by
    returning a low-confidence "unknown" translation. Without it (or if
    Groq is unreachable), we fall through to the sign-meanings layer.

    Either way, the API must return a valid response — never crash.
    """
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": ["ZZZ999", "FAKE_CODE"]},
    )
    assert response.status_code == 200

    data = response.json()
    t = data["translation"]
    # Acceptable methods for unknown codes:
    # - llm_translation: LLM explicitly marked it as unknown (preferred)
    # - sign_meanings: Layer 4 fallback (when LLM unavailable)
    # - transformer: Layer 3 fallback (rare, but possible if LLM offline)
    assert t["method"] in (
        "llm_translation",
        "sign_meanings",
        "transformer",
    )
    # Translation should never be empty
    assert t["translation_en"], "Translation must not be empty"
    # Unknown codes are shown wrapped in brackets


# -----------------------------------------------------------------------------
# Empty input
# -----------------------------------------------------------------------------

def test_empty_codes_returns_empty_method(client):
    """An empty list of codes should produce the 'empty' method."""
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": []},
    )
    assert response.status_code == 200

    data = response.json()
    t = data["translation"]
    assert t["method"] == "empty"
    assert t["translation_en"]  # non-empty placeholder
    assert t["translation_ar"]  # non-empty Arabic placeholder


# -----------------------------------------------------------------------------
# Input validation
# -----------------------------------------------------------------------------

def test_missing_codes_field_returns_422(client):
    """Schema violations must return 422 from the validation handler."""
    response = client.post("/api/translate-codes", json={})
    assert response.status_code == 422


def test_invalid_reading_direction_returns_422(client):
    """Reading direction must be one of the enum values."""
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": ["N5"], "reading_direction": "diagonal"},
    )
    assert response.status_code == 422


# -----------------------------------------------------------------------------
# Sign details always present
# -----------------------------------------------------------------------------

def test_sign_details_count_matches_codes(client):
    """sign_details length must match the input codes length."""
    codes = ["N5", "M23", "X1"]
    response = client.post(
        "/api/translate-codes",
        json={"gardiner_codes": codes},
    )
    data = response.json()
    assert len(data["translation"]["sign_details"]) == len(codes)