#!/usr/bin/env bash
# Create the Vagrant VirtualBox VMs (1 master, 2 workers, optional helper).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v vagrant >/dev/null 2>&1; then
  echo "Install Vagrant: https://developer.hashicorp.com/vagrant/install" >&2
  exit 1
fi

if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "Install VirtualBox and ensure VBoxManage is on PATH." >&2
  exit 1
fi

export LAB_PROFILE="${LAB_PROFILE:-prep}"
export LAB_HELPER="${LAB_HELPER:-true}"

echo "Profile=${LAB_PROFILE} helper=${LAB_HELPER}"
echo "This starts VMs and prepares them. It does not install OpenShift."
vagrant up
vagrant status
