#!/usr/bin/env bash
# Smoke-test the deployed lab app through its OpenShift Route.
set -euo pipefail

PROJECT="${PROJECT:-lab-hello}"
APP_NAME="${APP_NAME:-lab-hello}"

if ! command -v oc >/dev/null 2>&1; then
  echo "oc is not on PATH. Run: eval \$(crc oc-env)" >&2
  exit 1
fi

oc get nodes
oc get pods -n "${PROJECT}"
oc get route "${APP_NAME}" -n "${PROJECT}"

HOST="$(oc get route "${APP_NAME}" -n "${PROJECT}" -o jsonpath='{.spec.host}')"
URL="https://${HOST}"

echo "Checking ${URL}/healthz"
curl -fsSk "${URL}/healthz"
echo
echo "Checking ${URL}/info"
curl -fsSk "${URL}/info"
echo
echo "OK: ${URL}"
