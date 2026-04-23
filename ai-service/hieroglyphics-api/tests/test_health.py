"""
Tests for GET /api/health.
"""


def test_health_returns_200(client):
    """The health endpoint always returns HTTP 200."""
    response = client.get("/api/health")
    assert response.status_code == 200


def test_health_reports_healthy_when_models_loaded(client):
    """Once the lifespan has run, status should be 'healthy'."""
    response = client.get("/api/health")
    data = response.json()
    assert data["status"] == "healthy"
    assert data["models_loaded"] is True


def test_health_reports_version(client):
    """Response should include the configured app version."""
    response = client.get("/api/health")
    data = response.json()
    assert data["version"]  # non-empty
    assert isinstance(data["version"], str)


def test_health_reports_device(client):
    """Device field should be 'cpu' or 'cuda' (or 'cuda:N')."""
    response = client.get("/api/health")
    data = response.json()
    assert data["device"] in ("cpu", "cuda") or data["device"].startswith("cuda:")


def test_health_schema_shape(client):
    """Health response must have exactly these keys."""
    response = client.get("/api/health")
    data = response.json()
    assert set(data.keys()) == {"status", "version", "models_loaded", "device"}