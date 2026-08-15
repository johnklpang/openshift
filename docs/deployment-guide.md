# Deployment Guide

Create **1 master + 3 worker** VirtualBox VMs with Vagrant and prepare them for OpenShift.

This does **not** install OpenShift. It builds the machines, DNS, and load balancer you need before `openshift-install`.

## 1. Prerequisites

### Hardware

| Goal | Host RAM | Free disk | CPU |
|---|---|---|---|
| Prepare VMs only (`LAB_PROFILE=prep`) | 16 GB | 80 GB | 4 cores, VT-x/AMD-V on |
| Attempt a lab install later (`LAB_PROFILE=install`) | 32 GB or more | 200 GB | 8 cores preferred |

Enable virtualization in BIOS. On Windows, **do not enable Hyper-V** if you want VirtualBox to run these VMs. Hyper-V and VirtualBox conflict.

### Software

- [VirtualBox](https://www.virtualbox.org/) 7.x (include the Extension Pack if you use it)
- [Vagrant](https://developer.hashicorp.com/vagrant/install) 2.4+
- Git, and this repository
- Optional later: Red Hat pull secret from [Hybrid Cloud Console](https://console.redhat.com/openshift/create/local)

Check:

```bash
VBoxManage --version
vagrant version
```

### Windows notes

- Use PowerShell or Git Bash from the repo root
- Disable Hyper-V / Windows Hypervisor Platform if `vagrant up` fails with VT-x locked
- Allow the VirtualBox Host-Only adapter (`192.168.56.0/24`)

### Linux notes

```bash
# Fedora / RHEL family
sudo dnf install -y vagrant VirtualBox
# Ubuntu / Debian
sudo apt install -y vagrant virtualbox
```

Add your user to the `vboxusers` group and log out.

## 2. Create the VMs

From the repository root:

```bash
chmod +x scripts/*.sh
./scripts/cluster-up.sh
```

Equivalent:

```bash
# default: prep profile, helper + master + 3 workers
vagrant up
```

First run downloads the `bento/rockylinux-9` box (several GB) and can take 20–40 minutes.

### Profiles

```bash
# 16 GB laptop — prepare only
LAB_PROFILE=prep vagrant up

# 32 GB+ host — larger VMs for a later install attempt
LAB_PROFILE=install vagrant up

# Cluster nodes only (you already have DNS/LB)
LAB_HELPER=false vagrant up
```

Bring up one machine:

```bash
vagrant up helper
vagrant up master
vagrant up worker1 worker2 worker3
```

## 3. Verify the lab is prepared

```bash
./scripts/cluster-status.sh
vagrant status
```

SSH:

```bash
vagrant ssh helper
vagrant ssh master
vagrant ssh worker1
```

On any node:

```bash
hostname -f
cat /etc/ocp-lab/node.env
swapon --show          # must be empty
sysctl net.ipv4.ip_forward
getent hosts api.ocp.lab.local master.ocp.lab.local worker1.ocp.lab.local
```

On the helper:

```bash
systemctl is-active haproxy dnsmasq httpd
ss -lnt | grep -E '80|443|6443|22623'
```

From the host (if `192.168.56.9` is reachable):

```bash
ping -c 1 192.168.56.10
```

Expected inventory (`vagrant/inventory/hosts.ini`):

| Name | IP | Role |
|---|---|---|
| helper | 192.168.56.9 | DNS / HAProxy / bastion |
| master | 192.168.56.10 | Control plane |
| worker1 | 192.168.56.11 | Worker |
| worker2 | 192.168.56.12 | Worker |
| worker3 | 192.168.56.13 | Worker |

## 4. What is ready vs what is not

Ready:

- Four (or five) Rocky 9 VMs on the host-only network
- Swap off, forwarding on, OpenShift ports open
- DNS names for `api`, `api-int`, `*.apps`, and each node
- HAProxy frontends for API and ingress
- HTTP tree `/var/www/html/install` on the helper

Not done:

- No `oc` cluster, no console, no CRI-O cluster
- Master is not yet a Kubernetes control plane
- The test app cannot be deployed until OpenShift (or another Kubernetes) is installed

## 5. Next: OpenShift install (after you have RAM)

Use the helper as the bastion.

1. Copy a pull secret to the helper (never commit it).
2. Copy `vagrant/install-config.yaml.template` and fill `pullSecret` and `sshKey`.
3. Download `openshift-install` and `oc` for your OCP/OKD version onto the helper.
4. Generate Ignition configs and serve them from `http://192.168.56.9/install/`.
5. Reboot nodes into **RHCOS/FCOS** (normal OCP 4 UPI) **or** follow the current Red Hat UPI document for your version.

A 1-master cluster is unsupported for production. Prefer 3 masters when you have the hardware.

On a 16 GB laptop, stop here and use CRC if you need a working API today (appendix A).

## 6. Deploy the test app (only after a cluster exists)

```bash
eval $(crc oc-env)    # or use oc from the helper
oc login -u kubeadmin https://api.ocp.lab.local:6443
./scripts/deploy.sh
./scripts/verify.sh
```

On a Vagrant UPI cluster, create the project and apply `manifests/` the same way. Change the Route hostname if your apps domain is `*.apps.ocp.lab.local`.

App unit tests (no cluster):

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
pytest
```

## 7. Tear down

```bash
./scripts/cluster-down.sh          # vagrant halt — keep disks
./scripts/cluster-down.sh destroy  # delete all VMs
vagrant destroy -f
```

## Appendix A — CRC on a 16 GB laptop

If you need a **running** OpenShift API on 16 GB, do not use the 1+3 Vagrant cluster. Use OpenShift Local (single node):

```bash
crc config set preset openshift
crc config set cpus 4
crc config set memory 10752
crc setup
crc start
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443
./scripts/deploy.sh
```

Do not run CRC inside a Vagrant VM (nested virtualization is unsupported).
