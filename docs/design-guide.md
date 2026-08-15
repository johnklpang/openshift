# Design Guide

Lab design for a **1 master + 3 worker** OpenShift environment. Vagrant creates the VirtualBox VMs and prepares them for a later OpenShift install.

## 1. Purpose

This lab exists to:

- Spin up a repeatable multi-node topology with Vagrant
- Prepare hostnames, DNS, load balancing, kernel, and firewall for OpenShift UPI
- Keep a tiny test app ready to deploy after the cluster exists

It is **not** a production or HA control plane. One master is a single point of failure.

## 2. Constraints

| Constraint | Impact |
|---|---|
| Personal laptop, often 16 GB RAM | Vagrant can **create and prepare** 4–5 VMs. A real OpenShift 4 install of 1+3 does **not** fit in 16 GB |
| VirtualBox + Vagrant | Native hypervisor for this path. Do not nest CRC inside these VMs |
| Lab / learning | No HA masters, no production storage, no extra Operators |

Two profiles:

| Profile | Host RAM needed | What you get |
|---|---|---|
| `prep` (default) | 16 GB | VMs boot; packages, DNS, HAProxy, sysctl applied. Too small to install OCP |
| `install` | 32 GB or more | Sizes closer to a lab install (still below official Red Hat minimums) |

Official OpenShift 4 minimums are **16 GB per control-plane node** and **8 GB per worker**. A 1+3 install at those sizes needs about 40 GB for the VMs plus the host OS.

On a 16 GB laptop, use this Vagrant lab to practice node prep. To **run** OpenShift on that laptop, use the CRC single-node path in the [deployment guide](deployment-guide.md#appendix-a-crc-on-a-16-gb-laptop).

## 3. Topology

```
Host (VirtualBox + Vagrant)
 │
 ├── helper   192.168.56.9    DNS, HAProxy, HTTP, bastion   (optional, default on)
 ├── master   192.168.56.10   control plane (1)
 ├── worker1  192.168.56.11   compute
 ├── worker2  192.168.56.12   compute
 └── worker3  192.168.56.13   compute
```

Cluster DNS name: `ocp.lab.local`

| Record | Address | Role |
|---|---|---|
| `api.ocp.lab.local` | helper | Kubernetes API VIP (HAProxy :6443) |
| `api-int.ocp.lab.local` | helper | Internal API / MCS (:6443, :22623) |
| `*.apps.ocp.lab.local` | helper | Ingress VIP (HAProxy :80/:443) |
| `master.ocp.lab.local` | 192.168.56.10 | Control plane |
| `workerN.ocp.lab.local` | 192.168.56.11–13 | Workers |

The helper is **not** an OpenShift node. OpenShift 4 UPI needs a load balancer and DNS in front of the nodes. The helper is that appliance.

Disable it with `LAB_HELPER=false` if you will supply your own DNS/LB.

## 4. Resource budget

### 4.1 `prep` profile (16 GB host)

| VM | vCPU | RAM | Disk (box default) |
|---|---|---|---|
| helper | 1 | 1 GB | ~20 GB |
| master | 2 | 2 GB | ~40 GB |
| worker ×3 | 1 | 1.5 GB | ~30 GB |
| **VMs total** | 6 | **7.5 GB** | |
| Host OS | — | ~5–8 GB | |

This is enough to `vagrant up` and inspect prepared nodes. It is **not** enough to start `kube-apiserver`, etcd, and OVN.

### 4.2 `install` profile (32 GB+ host)

| VM | vCPU | RAM |
|---|---|---|
| helper | 2 | 2 GB |
| master | 4 | 8 GB |
| worker ×3 | 2 | 6 GB |
| **VMs total** | 12 | **28 GB** |

Still below official minimums. Expect a slow cluster if you proceed to install.

## 5. What Vagrant prepares (not what it installs)

Each node script (`vagrant/provision/common.sh`) does the following:

- Sets FQDN and `/etc/hosts`
- Disables swap (required)
- Enables chrony / NTP
- Loads `overlay` and `br_netfilter`
- Sets `ip_forward` and bridge netfilter sysctls
- Installs baseline packages (`python3`, `jq`, `bind-utils`, NetworkManager)
- Opens OpenShift ports in firewalld
- Writes `/etc/ocp-lab/node.env`

The helper also installs:

- **dnsmasq** — `api`, `api-int`, `*.apps`, node names
- **HAProxy** — 6443, 22623, 80, 443
- **httpd** — `/var/www/html/install` for later Ignition or images

OpenShift itself (RHCOS, CRI-O, cluster Operators) is a **later** step. Current OpenShift 4 control-plane nodes are meant to boot **RHCOS/FCOS** with Ignition. These Rocky 9 VMs are the network and OS-prep layer, and a bastion from which you run `openshift-install`.

## 6. Vagrant design choices

| Choice | Reason |
|---|---|
| VirtualBox provider | Matches a personal-laptop lab |
| `bento/rockylinux-9` | RHEL-compatible, no subscription to boot VMs |
| Linked clones | Faster `vagrant up`, less disk |
| Default synced folder off | Avoids Guest Additions / vboxsf failures |
| Host-only `192.168.56.0/24` | Stable IPs on VirtualBox |
| NAT + host-only | NAT for `dnf`; host-only for cluster traffic |

## 7. Test application

`app/` is unchanged: a Flask smoke test (`/`, `/healthz`, `/readyz`, `/info`) deployed after a cluster exists. See [deployment guide](deployment-guide.md).

## 8. Security (lab only)

- Host-only network is local to the laptop
- `vagrant` / default box credentials are lab-only
- Pull secrets and SSH keys stay out of git
- Do not port-forward API or ingress to the internet

## 9. Related documents

- [Deployment guide](deployment-guide.md) — install Vagrant/VirtualBox and `vagrant up`
- [Runbook](runbook.md) — start/stop, SSH, common VM failures
