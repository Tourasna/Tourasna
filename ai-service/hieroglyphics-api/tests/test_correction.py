"""
Tests for the interactive correction endpoints:
  GET /api/sign/{code}/info
  GET /api/signs/search

These power the Human-in-the-Loop correction UI.
"""

# =============================================================================
# GET /api/sign/{code}/info
# =============================================================================

def test_sign_info_returns_200_for_known_code(client):
    """Looking up a known Gardiner code returns 200."""
    response = client.get("/api/sign/D21/info")
    assert response.status_code == 200


def test_sign_info_returns_correct_data_for_d21(client):
    """D21 (mouth) returns the expected bilingual info."""
    data = client.get("/api/sign/D21/info").json()
    assert data["code"] == "D21"
    assert data["name_en"] == "mouth"
    assert data["name_ar"]  # Arabic name populated
    assert data["transliteration"] == "r"
    assert "Body parts" in data["category"]


def test_sign_info_includes_common_confusions(client):
    """D21 has known visual confusions with D4, D40, F12."""
    data = client.get("/api/sign/D21/info").json()
    assert "common_confusions" in data
    confusions = data["common_confusions"]
    # At least one of the expected confusions should be there
    assert any(c in confusions for c in ["D4", "D40", "F12"])


def test_sign_info_returns_404_for_unknown_code(client):
    """Unknown codes return 404, not 500."""
    response = client.get("/api/sign/ZZ999/info")
    assert response.status_code == 404


def test_sign_info_schema_has_all_required_fields(client):
    """Response must have all SignInfoDetailed fields."""
    data = client.get("/api/sign/N5/info").json()
    required_keys = {
        "code",
        "name_en",
        "name_ar",
        "transliteration",
        "category",
        "common_confusions",
        "image_url",
        "examples",
        "meaning_notes",
    }
    assert set(data.keys()) == required_keys


# =============================================================================
# GET /api/signs/search
# =============================================================================

def test_search_returns_200(client):
    """Basic search returns 200."""
    response = client.get("/api/signs/search?q=mouth")
    assert response.status_code == 200


def test_search_finds_d21_by_english_name(client):
    """Searching 'mouth' must find D21."""
    data = client.get("/api/signs/search?q=mouth").json()
    codes = [r["code"] for r in data["results"]]
    assert "D21" in codes


def test_search_finds_n5_by_transliteration(client):
    """Searching 'ra' must find N5 (sun god Ra)."""
    data = client.get("/api/signs/search?q=ra").json()
    codes = [r["code"] for r in data["results"]]
    assert "N5" in codes


def test_search_finds_by_code_prefix(client):
    """Searching 'D2' should find D21."""
    data = client.get("/api/signs/search?q=D2").json()
    codes = [r["code"] for r in data["results"]]
    assert "D21" in codes


def test_search_total_matches_results_length(client):
    """`total` field must match results length."""
    data = client.get("/api/signs/search?q=mouth").json()
    assert data["total"] == len(data["results"])


def test_search_respects_limit(client):
    """The limit parameter caps the number of results."""
    data = client.get("/api/signs/search?q=a&limit=3").json()
    assert len(data["results"]) <= 3


def test_search_missing_query_returns_422(client):
    """Missing required q parameter returns 422."""
    response = client.get("/api/signs/search")
    assert response.status_code == 422


def test_search_results_have_score_field(client):
    """Every result must have a relevance score between 0 and 1."""
    data = client.get("/api/signs/search?q=mouth").json()
    for result in data["results"]:
        assert "score" in result
        assert 0.0 <= result["score"] <= 1.0