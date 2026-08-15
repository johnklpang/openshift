from app import app


def test_healthz():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_readyz():
    client = app.test_client()
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ready"


def test_info_and_home():
    client = app.test_client()
    info = client.get("/info")
    assert info.status_code == 200
    body = info.get_json()
    assert body["status"] == "ok"
    assert body["app"]
    assert body["hostname"]

    home = client.get("/")
    assert home.status_code == 200
    assert b"OpenShift lab test app is running" in home.data
