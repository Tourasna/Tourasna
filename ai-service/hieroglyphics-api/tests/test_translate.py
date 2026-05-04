"""
Tests for POST /api/translate — the full image-based pipeline.

These tests are slower (~5-10s each) because they run the full
YOLO + sorter + translator pipeline on a real image.
"""
import pytest


def test_translate_rejects_missing_image(client):
    """No image -> 422 validation error."""
    response = client.post("/api/translate")
    assert response.status_code == 422


def test_translate_rejects_wrong_content_type(client):
    """Sending a .txt file should be rejected with 415."""
    response = client.post(
        "/api/translate",
        files={"image": ("fake.txt", b"not an image", "text/plain")},
    )
    assert response.status_code == 415


def test_translate_rejects_empty_upload(client):
    """An empty image body must return 400."""
    response = client.post(
        "/api/translate",
        files={"image": ("empty.jpg", b"", "image/jpeg")},
    )
    # Empty body fails either at size check (400) or decode (400).
    assert response.status_code == 400


def test_translate_rejects_corrupt_image(client):
    """Gibberish bytes with an image content-type should fail decoding."""
    response = client.post(
        "/api/translate",
        files={"image": ("bad.jpg", b"not-a-real-jpeg-file", "image/jpeg")},
    )
    assert response.status_code == 400


# -----------------------------------------------------------------------------
# Real image pipeline test
# -----------------------------------------------------------------------------

@pytest.mark.slow
def test_translate_ramesses_pipeline(client, ramesses_image_bytes):
    """
    Full end-to-end: upload Ramesses cartouche image, expect detections
    and a translation. This is the smoke test for the whole service.
    """
    response = client.post(
        "/api/translate",
        files={
            "image": (
                "RamsesII_cartouche.jpg",
                ramesses_image_bytes,
                "image/jpeg",
            ),
        },
        data={"reading_direction": "rtl"},
    )

    assert response.status_code == 200
    data = response.json()

    # Image metadata
    assert data["image_size"]["width"] > 0
    assert data["image_size"]["height"] > 0
    assert data["reading_direction"] == "rtl"

    # Detector produced something
    assert data["total_detections"] > 0
    assert data["rows"] >= 1
    assert data["quadrats"] >= 1
    assert len(data["detections"]) == data["total_detections"]

    # Each detection has reading-order fields populated
    for det in data["detections"]:
        assert det["id"] > 0
        assert det["row"] >= 1
        assert det["quadrat_id"] >= 1
        assert det["position_in_quadrat"] >= 1
        assert 0.0 <= det["confidence"] <= 1.0

    # Sequence matches detections order
    assert data["gardiner_sequence"] == [
        d["gardiner_code"] for d in data["detections"]
    ]

    # Some translation was produced
    t = data["translation"]
    assert t["method"] in (
            "database_exact",
            "llm_translation",
            "transformer",
            "sign_meanings",
            "empty",
        )
    assert t["translation_en"]
    assert len(t["sign_details"]) == data["total_detections"]