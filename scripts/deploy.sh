#!/usr/bin/env bash
# Build and deploy the lab test app to a running CRC/OpenShift cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-lab-hello}"
APP_NAME="${APP_NAME:-lab-hello}"

if ! command -v oc >/dev/null 2>&1; then
  echo "oc is not on PATH. Run: eval \$(crc oc-env)" >&2
  exit 1
fi

if ! oc whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: oc login -u developer https://api.crc.testing:6443" >&2
  exit 1
fi

oc new-project "${PROJECT}" >/dev/null 2>&1 || true
oc project "${PROJECT}" >/dev/null

if ! oc get bc "${APP_NAME}" >/dev/null 2>&1; then
  oc new-build --name="${APP_NAME}" --binary --strategy=docker
fi

oc start-build "${APP_NAME}" --from-dir="${ROOT}/app" --follow

oc apply -f "${ROOT}/manifests/namespace.yaml"
oc apply -f "${ROOT}/manifests/deployment.yaml"
oc apply -f "${ROOT}/manifests/service.yaml"
oc apply -f "${ROOT}/manifests/route.yaml"

oc rollout status deploy/"${APP_NAME}" -n "${PROJECT}" --timeout=180s
echo
echo "Route:"
oc get route "${APP_NAME}" -n "${PROJECT}" -o jsonpath='https://{.spec.host}{"\n"}'
