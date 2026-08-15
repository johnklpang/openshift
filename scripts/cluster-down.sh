#!/usr/bin/env bash
# Stop or destroy the Vagrant lab VMs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

MODE="${1:-halt}"

case "${MODE}" in
  halt|stop)
    vagrant halt
    ;;
  destroy)
    vagrant destroy -f
    ;;
  *)
    echo "Usage: $0 [halt|destroy]" >&2
    exit 1
    ;;
esac
