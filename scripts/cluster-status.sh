#!/usr/bin/env bash
# Show Vagrant VM state and basic node readiness markers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v vagrant >/dev/null 2>&1; then
  echo "vagrant is not installed." >&2
  exit 1
fi

vagrant status
echo

for node in helper master worker1 worker2; do
  if vagrant status "${node}" 2>/dev/null | grep -q running; then
    echo "---- ${node} ----"
    vagrant ssh "${node}" -c 'set -e; echo "$(hostname -f) $(hostname -I)"; cat /etc/ocp-lab/node.env; swapon --show || true' || true
    echo
  fi
done
