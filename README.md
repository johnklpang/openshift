# OpenShift laptop lab

Single-node **Red Hat OpenShift** lab for a personal laptop with **16 GB RAM**, plus a tiny app used to prove the cluster works.

This is not a multi-node or production install. Do not nest OpenShift inside VirtualBox.

## Documents

| Guide | What it covers |
|---|---|
| [Design guide](docs/design-guide.md) | Architecture, 16 GB resource budget, why CRC, app design |
| [Deployment guide](docs/deployment-guide.md) | Install CRC, start the cluster, deploy the test app |
| [Runbook](docs/runbook.md) | Daily start/stop, health checks, incident procedures |

## Minimum node

One CRC virtual machine. One OpenShift node. One replica of the test app.

```
Host (16 GB)
 └── CRC VM  (4 vCPU / 10.5 GB)   native hypervisor, not VirtualBox
      └── OpenShift single node
           └── lab-hello  (Flask, 64–128 Mi)
```

## Quick start

1. Download [OpenShift Local](https://console.redhat.com/openshift/create/local) and a pull secret.
2. Follow the [deployment guide](docs/deployment-guide.md).
3. Deploy and verify the test app:

```bash
crc start
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443
./scripts/deploy.sh
./scripts/verify.sh
```

## Test app

`app/` is a Flask service with:

- `/` HTML status page
- `/healthz` liveness
- `/readyz` readiness
- `/info` JSON (hostname, version)

OpenShift objects live in `manifests/`.

Unit tests (no cluster required):

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
pytest
```

## Daily commands

```bash
crc status
crc stop
crc start
crc delete -f
```

If the 10.5 GB OpenShift preset makes the laptop swap, switch to MicroShift as described in the deployment guide.
