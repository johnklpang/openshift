# Design Guide

Lab design for a **single-node Red Hat OpenShift** environment on a personal laptop with **16 GB RAM**, plus a tiny smoke-test application.

## 1. Purpose

This lab exists to:

- Learn OpenShift Container Platform (OCP) on one machine
- Practice `oc`, Routes, Deployments, health probes, and image builds
- Validate that the cluster can schedule and expose a real application

It is **not** a production, HA, or performance environment.

## 2. Constraints

| Constraint | Impact |
|---|---|
| 16 GB host RAM | One node only; leave ~5 GB for the host OS |
| Personal laptop | Ephemeral cluster; no shared multi-user tenancy |
| VirtualBox installed | Do **not** nest OpenShift inside a VirtualBox VM |
| Lab / learning | Monitoring and extra Operators stay off |

**Minimum topology:** 1 virtual machine, 1 OpenShift node (control plane + worker combined).

A 3-node IPI/UPI cluster (bootstrap + master + worker) does not fit in 16 GB.

## 3. Chosen platform

**Red Hat OpenShift Local** (`crc`, formerly CodeReady Containers) is the supported laptop distribution of OCP.

```
┌─────────────────────────────────────────────┐
│ Host OS (Windows / macOS / Linux)  ~5 GB    │
│                                             │
│   Native hypervisor                         │
│   (Hyper-V / HyperKit-vfkit / KVM)          │
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │ CRC VM  4 vCPU / 10.5 GB / 35 GB    │   │
│   │                                     │   │
│   │  Single OpenShift node              │   │
│   │  api.crc.testing                    │   │
│   │  *.apps-crc.testing                 │   │
│   │                                     │   │
│   │  namespace lab-hello                │   │
│   │    Deployment/Service/Route         │   │
│   │    lab-hello app (64–128 Mi)        │   │
│   └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

CRC creates and manages the VM. You do not create that VM in VirtualBox.

### 3.1 Why not VirtualBox for CRC

- Current OpenShift Local **does not support VirtualBox**
- CRC **does not support nested virtualization**
- On Windows, Hyper-V and VirtualBox conflict

VirtualBox can still host a **separate** RHEL VM running MicroShift if you refuse native hypervisors. That path is a fallback, not the primary design.

### 3.2 Presets

| Preset | What you get | Cluster RAM | Use when |
|---|---|---|---|
| `openshift` | Full single-node OCP (console, Operators, Routes) | 10.5 GB | You want real OpenShift |
| `microshift` | Lightweight Kubernetes + OpenShift subset | 4 GB | Host is swapping or you need headroom |
| `okd` | Community OpenShift | 10.5 GB | No Red Hat pull secret |

**Default for this lab:** `openshift`.

## 4. Resource budget (16 GB host)

| Consumer | Allocation |
|---|---|
| Host OS + browser + terminal | ~5 GB |
| CRC VM | 4 vCPU, **10752 MiB**, 35 GB disk |
| OpenShift system pods | Most of the VM |
| `lab-hello` test app | 1 replica, 64 Mi request / 128 Mi limit |

Do not set CRC memory to 16384. That starves the host and usually makes the laptop unusable.

If the host swaps after `crc start`, switch preset to `microshift` (see the [deployment guide](deployment-guide.md)).

## 5. Network and identity

| Name | Value |
|---|---|
| API | `https://api.crc.testing:6443` |
| Console | `https://console-openshift-console.apps-crc.testing` |
| App routes | `https://<route>.apps-crc.testing` |
| Users | `developer` (apps), `kubeadmin` (admin) |
| Pull secret | Red Hat Hybrid Cloud Console (required for `openshift` preset) |

CRC configures host DNS for `*.crc.testing` and `*.apps-crc.testing`. VPN clients often break this.

## 6. Test application design

The repo ships `app/` — a one-process Flask service used only to prove the platform works.

### 6.1 Responsibilities

- Serve a visible HTML page at `/`
- Expose `/healthz` (liveness) and `/readyz` (readiness)
- Expose `/info` JSON (hostname + version) so you can confirm which pod answered

### 6.2 Runtime choices

| Choice | Reason |
|---|---|
| UBI 9 Python 312 | Red Hat base image; works with CRC internal registry |
| Port 8080 | OpenShift non-root default |
| gunicorn, 1 worker | Tiny memory footprint |
| `runAsNonRoot`, drop all capabilities | Matches restricted SCC |
| 1 replica | Minimum node / minimum RAM |

### 6.3 OpenShift objects

```
Namespace lab-hello
  └── Deployment lab-hello (1 pod)
        └── Service lab-hello :8080
              └── Route lab-hello (edge TLS)
```

Images are built on-cluster with `oc new-app --strategy=docker` so you do not need a public registry.

## 7. Security (lab only)

- Cluster is bound to the laptop; do not expose CRC ports to the internet
- Treat `kubeadmin` as break-glass; use `developer` for app work
- Pull secret stays out of git (see `.gitignore`)
- App runs as UID 1001, no privileged containers

## 8. What this design explicitly excludes

- Multi-node HA, machine API, bare-metal IPI
- OpenShift Virtualization / nested VMs
- Cluster monitoring stack (disabled by default on CRC)
- Persistent production storage and backup
- Service Mesh, Pipelines, GitOps Operators (too heavy for 16 GB)

## 9. Related documents

- [Deployment guide](deployment-guide.md) — install CRC and deploy the app
- [Runbook](runbook.md) — daily ops and failure recovery
