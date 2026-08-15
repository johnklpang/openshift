#!/usr/bin/env bash
# Extra control-plane prep. OpenShift itself is installed later.
set -euo pipefail

# Control plane needs a bit more process map headroom on small VMs.
cat >/etc/sysctl.d/99-openshift-master.conf <<'EOF'
vm.max_map_count = 262144
fs.inotify.max_user_watches = 65536
EOF
sysctl --system >/dev/null

echo "==> master extras complete"
