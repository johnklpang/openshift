#!/usr/bin/env bash
# Bastion services: DNS (dnsmasq), load balancer (HAProxy), HTTP for install artifacts.
set -euo pipefail

DOMAIN="${1:?domain}"
HELPER_IP="${2:?helper ip}"
MASTER_IP="${3:?master ip}"
WORKER1_IP="${4:?worker1 ip}"
WORKER2_IP="${5:?worker2 ip}"
WORKER3_IP="${6:?worker3 ip}"

dnf -y install haproxy dnsmasq httpd

install -m 0644 /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
sed -i \
  -e "s/__MASTER_IP__/${MASTER_IP}/g" \
  -e "s/__WORKER1_IP__/${WORKER1_IP}/g" \
  -e "s/__WORKER2_IP__/${WORKER2_IP}/g" \
  -e "s/__WORKER3_IP__/${WORKER3_IP}/g" \
  /etc/haproxy/haproxy.cfg

install -m 0644 /tmp/dnsmasq.conf /etc/dnsmasq.d/ocp-lab.conf
sed -i \
  -e "s/__DOMAIN__/${DOMAIN}/g" \
  -e "s/__HELPER_IP__/${HELPER_IP}/g" \
  -e "s/__MASTER_IP__/${MASTER_IP}/g" \
  -e "s/__WORKER1_IP__/${WORKER1_IP}/g" \
  -e "s/__WORKER2_IP__/${WORKER2_IP}/g" \
  -e "s/__WORKER3_IP__/${WORKER3_IP}/g" \
  /etc/dnsmasq.d/ocp-lab.conf

# Keep the system resolver on NAT; only listen on the host-only address.
if [ -f /etc/dnsmasq.conf ]; then
  grep -q '^conf-dir=/etc/dnsmasq.d' /etc/dnsmasq.conf || echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf
fi

mkdir -p /var/www/html/install
cat >/var/www/html/index.html <<EOF
<html><body><p>OpenShift lab helper (${DOMAIN})</p></body></html>
EOF

setsebool -P haproxy_connect_any 1 || true
systemctl enable --now haproxy dnsmasq httpd
systemctl restart haproxy dnsmasq httpd

echo "==> helper services: haproxy, dnsmasq, httpd"
