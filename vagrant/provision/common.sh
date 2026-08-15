#!/usr/bin/env bash
# Prepare a Rocky/RHEL 9 VM for a later OpenShift UPI install.
set -euo pipefail

HOSTNAME_SHORT="${1:?hostname}"
NODE_IP="${2:?ip}"
ROLE="${3:?role}"
DOMAIN="${4:?domain}"
NETWORK="${5:?network prefix}"

FQDN="${HOSTNAME_SHORT}.${DOMAIN}"

echo "==> Preparing ${FQDN} (${NODE_IP}) role=${ROLE}"

hostnamectl set-hostname "${FQDN}"

# Keep Vagrant NAT DNS, then append cluster names.
if ! grep -q "ocp-lab-hosts" /etc/hosts; then
  cat >> /etc/hosts <<EOF
# ocp-lab-hosts
${NETWORK}.9 helper.${DOMAIN} helper api.${DOMAIN} api-int.${DOMAIN}
${NETWORK}.10 master.${DOMAIN} master
${NETWORK}.11 worker1.${DOMAIN} worker1
${NETWORK}.12 worker2.${DOMAIN} worker2
EOF
fi

# OpenShift nodes must not use swap.
swapoff -a || true
if grep -qE '^[^#].+\sswap\s' /etc/fstab; then
  sed -i.bak -E 's/^([^#].+\sswap\s)/# \1/' /etc/fstab
fi

timedatectl set-ntp true || true

dnf -y install \
  bash-completion \
  bind-utils \
  chrony \
  curl \
  git \
  iproute \
  iptables \
  jq \
  NetworkManager \
  net-tools \
  python3 \
  tar \
  tmux \
  vim-enhanced \
  wget

systemctl enable --now chronyd NetworkManager

modprobe overlay || true
modprobe br_netfilter || true
cat >/etc/modules-load.d/openshift.conf <<'EOF'
overlay
br_netfilter
EOF

cat >/etc/sysctl.d/99-openshift.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# Lab firewall: open the ports an OpenShift node or helper needs.
if systemctl list-unit-files | grep -q '^firewalld'; then
  systemctl enable --now firewalld
  firewall-cmd --permanent --add-service=ssh
  case "${ROLE}" in
    helper)
      firewall-cmd --permanent --add-service=http
      firewall-cmd --permanent --add-service=https
      firewall-cmd --permanent --add-service=dns
      firewall-cmd --permanent --add-port=6443/tcp
      firewall-cmd --permanent --add-port=22623/tcp
      firewall-cmd --permanent --add-port=9000/tcp
      ;;
    master)
      firewall-cmd --permanent --add-port=6443/tcp
      firewall-cmd --permanent --add-port=22623/tcp
      firewall-cmd --permanent --add-port=2379-2380/tcp
      firewall-cmd --permanent --add-port=10250/tcp
      firewall-cmd --permanent --add-port=10257/tcp
      firewall-cmd --permanent --add-port=10259/tcp
      firewall-cmd --permanent --add-port=4789/udp
      firewall-cmd --permanent --add-port=6081/udp
      firewall-cmd --permanent --add-port=9000-9999/tcp
      firewall-cmd --permanent --add-port=30000-32767/tcp
      ;;
    worker)
      firewall-cmd --permanent --add-port=10250/tcp
      firewall-cmd --permanent --add-port=4789/udp
      firewall-cmd --permanent --add-port=6081/udp
      firewall-cmd --permanent --add-port=9000-9999/tcp
      firewall-cmd --permanent --add-port=30000-32767/tcp
      firewall-cmd --permanent --add-service=http
      firewall-cmd --permanent --add-service=https
      ;;
  esac
  firewall-cmd --reload
fi

# Ready marker used by vagrant/status checks.
mkdir -p /etc/ocp-lab
cat >/etc/ocp-lab/node.env <<EOF
HOSTNAME_SHORT=${HOSTNAME_SHORT}
FQDN=${FQDN}
NODE_IP=${NODE_IP}
ROLE=${ROLE}
DOMAIN=${DOMAIN}
PREPARED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "==> ${FQDN} preparation complete"
