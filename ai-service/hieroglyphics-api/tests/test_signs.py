"""
Tests for GET /api/signs.
"""


def test_signs_returns_200(client):
    response = client.get("/api/signs")
    assert response.status_code == 200


def test_signs_total_matches_list_length(client):
    """`total` must equal len(signs) — guards against off-by-one bugs."""
    data = client.get("/api/signs").json()
    assert data["total"] == len(data["signs"])


def test_signs_contains_ramesses_codes(client):
    """The 5 signs used in the Ramesses cartouche must all be known."""
    data = client.get("/api/signs").json()
    codes = {sign["gardiner_code"] for sign in data["signs"]}
    expected = {"N5", "S29", "M23", "X1"}
    assert expected.issubset(codes), (
        f"Missing Ramesses signs. Have: {sorted(codes)[:10]}... "
        f"Missing: {expected - codes}"
    )


def test_each_sign_has_bilingual_meaning(client):
    """Every sign must have both English and Arabic meanings populated."""
    data = client.get("/api/signs").json()
    for sign in data["signs"]:
        code = sign["gardiner_code"]
        assert sign["meaning_en"], f"Sign {code} missing English meaning"
        assert sign["meaning_ar"], f"Sign {code} missing Arabic meaning"


def test_signs_schema_keys(client):
    """Every sign entry must have exactly these 5 fields."""
    data = client.get("/api/signs").json()
    expected_keys = {
        "gardiner_code",
        "meaning_en",
        "meaning_ar",
        "sound",
        "category",
    }
    for sign in data["signs"]:
        assert set(sign.keys()) == expected_keys