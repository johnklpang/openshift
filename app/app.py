"""Minimal OpenShift lab test app.

Serves a status page plus health endpoints so you can verify a
single-node CRC or MicroShift cluster after install.
"""

from __future__ import annotations

import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template_string

APP_NAME = os.environ.get("APP_NAME", "openshift-lab-hello")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
LISTEN_HOST = os.environ.get("LISTEN_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("PORT", "8080"))

app = Flask(__name__)

PAGE = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{{ name }}</title>
  <style>
    :root { color-scheme: dark; }
    body {
      font-family: ui-sans-serif, system-ui, sans-serif;
      margin: 0; min-height: 100vh;
      display: grid; place-items: center;
      background: #0f172a; color: #e2e8f0;
    }
    main {
      width: min(40rem, calc(100vw - 2rem));
      background: #1e293b; border: 1px solid #334155;
      border-radius: 1rem; padding: 1.5rem 1.75rem;
    }
    h1 { margin: 0 0 .4rem; font-size: 1.5rem; }
    .ok { color: #4ade80; font-weight: 700; }
    dl { display: grid; grid-template-columns: 8rem 1fr; gap: .4rem 1rem; }
    dt { color: #94a3b8; } dd { margin: 0; word-break: break-all; }
    a { color: #7dd3fc; }
  </style>
</head>
<body>
  <main>
    <h1>{{ name }}</h1>
    <p class="ok">OpenShift lab test app is running.</p>
    <dl>
      <dt>version</dt><dd>{{ version }}</dd>
      <dt>hostname</dt><dd>{{ hostname }}</dd>
      <dt>time (UTC)</dt><dd>{{ now }}</dd>
    </dl>
    <p>
      Health:
      <a href="/healthz">/healthz</a> ·
      <a href="/readyz">/readyz</a> ·
      <a href="/info">/info</a>
    </p>
  </main>
</body>
</html>
"""


def _info() -> dict[str, str]:
    return {
        "app": APP_NAME,
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "utc": datetime.now(timezone.utc).isoformat(),
        "status": "ok",
    }


@app.get("/")
def index():
    data = _info()
    return render_template_string(
        PAGE,
        name=data["app"],
        version=data["version"],
        hostname=data["hostname"],
        now=data["utc"],
    )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok"), 200


@app.get("/readyz")
def readyz():
    return jsonify(status="ready"), 200


@app.get("/info")
def info():
    return jsonify(_info()), 200


def create_app() -> Flask:
    return app


if __name__ == "__main__":
    app.run(host=LISTEN_HOST, port=LISTEN_PORT)
