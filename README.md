# OpenShift laptop lab

Vagrant + VirtualBox lab that spins up **1 master and 2 workers** (plus an optional helper) and **prepares** them for OpenShift.

This does not install OpenShift. The default `prep` profile is sized for a **16 GB** laptop. A real OpenShift 4 install of this topology still needs about 32 GB.

## Documents

| Guide | What it covers |
|---|---|
| [Design guide](docs/design-guide.md) | 1+2 topology, helper DNS/LB, `prep` vs `install` RAM |
| [Deployment guide](docs/deployment-guide.md) | Install Vagrant/VirtualBox, `vagrant up`, verify nodes |
| [Runbook](docs/runbook.md) | Start/stop, SSH, VT-x, network, provision failures |

## Topology

```
Host (VirtualBox)
 ├── helper   192.168.56.9     DNS, HAProxy, HTTP bastion
 ├── master   192.168.56.10    control plane
 ├── worker1  192.168.56.11
 └── worker2  192.168.56.12
```

Domain: `ocp.lab.local` (`api`, `api-int`, `*.apps` point at the helper).

## Quick start

```bash
# VirtualBox and Vagrant must already be installed
./scripts/cluster-up.sh
./scripts/cluster-status.sh
vagrant ssh master
```

Larger VMs (32 GB+ host) when you are ready to attempt an install:

```bash
LAB_PROFILE=install vagrant up
```

Stop or delete:

```bash
./scripts/cluster-down.sh
./scripts/cluster-down.sh destroy
```

## Test app

`app/` is a Flask smoke test (`/`, `/healthz`, `/readyz`, `/info`) for **after** a cluster exists. Manifests are in `manifests/`.

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
pytest
```

## 16 GB laptop

Use `LAB_PROFILE=prep` (default). Do not expect `oc login` to work against these VMs.

To run OpenShift on 16 GB, use OpenShift Local (CRC) as described in the [deployment guide appendix](docs/deployment-guide.md#appendix-a-crc-on-a-16-gb-laptop). Do not nest CRC inside a Vagrant VM.
