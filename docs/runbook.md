# Runbook

Operational procedures for the 16 GB single-node OpenShift lab and the `lab-hello` test app.

## 1. Roles and access

| Role | Account | Use |
|---|---|---|
| App developer | `developer` | Projects, builds, deploy, Routes |
| Cluster admin | `kubeadmin` | Nodes, operators, CRC-level repair |
| Host operator | laptop user | `crc setup|start|stop|delete` |

```bash
eval $(crc oc-env)
crc console --credentials
oc login -u developer https://api.crc.testing:6443
```

## 2. Daily operations

### Start the lab

1. Close heavy apps (Docker Desktop, extra browsers, other VMs).
2. Disconnect VPN.
3. Start the cluster:

```bash
crc start
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443
oc get nodes
```

4. Confirm the test app (if previously deployed):

```bash
./scripts/verify.sh
```

### Stop the lab

```bash
crc stop
```

Always stop CRC when you are done. The VM holds ~10.5 GB even when idle.

### Status

```bash
crc status
oc get nodes
oc get co                 # kubeadmin; some operators stay degraded on CRC
oc get pods -A
oc get pods,route -n lab-hello
```

## 3. Health checks

| Check | Command | Expected |
|---|---|---|
| CRC VM | `crc status` | VM Running, OpenShift Running |
| Node | `oc get nodes` | 1 node, Ready |
| App pods | `oc get pods -n lab-hello` | `1/1 Running` |
| Liveness | `curl -k https://<route>/healthz` | `{"status":"ok"}` |
| Readiness | `curl -k https://<route>/readyz` | `{"status":"ready"}` |
| Identity | `curl -k https://<route>/info` | hostname + version |

Get the route host:

```bash
oc get route lab-hello -n lab-hello -o jsonpath='{.spec.host}{"\n"}'
```

## 4. Deploy / redeploy the test app

```bash
./scripts/deploy.sh
./scripts/verify.sh
```

Force a new build from local sources:

```bash
oc start-build lab-hello --from-dir=./app --follow -n lab-hello
oc rollout status deploy/lab-hello -n lab-hello
```

Scale (keep at 1 on this laptop):

```bash
oc scale deploy/lab-hello --replicas=1 -n lab-hello
```

## 5. Common incidents

### 5.1 `crc start` fails: virtualization not enabled

**Symptom:** BIOS / Hyper-V / KVM preflight error.

**Action:**

1. Enable VT-x/AMD-V in firmware.
2. Windows: enable Hyper-V, reboot. Do not run CRC inside VirtualBox.
3. Linux: `lsmod | grep kvm` and install `libvirt`.
4. Re-run `crc setup && crc start`.

### 5.2 Host freezes or heavy swap after start

**Symptom:** Laptop unusable; disk thrashing.

**Action:**

```bash
crc stop
crc delete -f
crc config set preset microshift
crc config set cpus 2
crc config set memory 4096
crc setup
crc start
```

Do not raise CRC memory to 16 GB.

### 5.3 Cannot resolve `*.crc.testing`

**Symptom:** Browser or `oc login` cannot find the API or console.

**Action:**

1. Disconnect VPN.
2. `crc status` then `crc stop && crc start`.
3. Windows: confirm the CRC DNS service is running; avoid third-party DNS filters.
4. Try `crc console` (uses the configured host resolver).

### 5.4 `oc` command not found

```bash
eval $(crc oc-env)
# Windows PowerShell: crc oc-env | Invoke-Expression
```

### 5.5 Image pull / build errors

**Symptom:** BuildConfig fails; pods `ImagePullBackOff`.

**Action:**

1. Confirm pull secret: `crc config get pull-secret-file`.
2. Re-download the secret from Hybrid Cloud Console if it expired.
3. `oc logs bc/lab-hello -n lab-hello`.
4. Rebuild: `oc start-build lab-hello --from-dir=./app --follow -n lab-hello`.
5. `oc describe pod -n lab-hello` for pull errors.

### 5.6 App pod CrashLoopBackOff

```bash
oc logs deploy/lab-hello -n lab-hello
oc describe pod -n lab-hello
oc get events -n lab-hello --sort-by='.lastTimestamp'
```

Confirm the container listens on **8080** and probes hit `/healthz` and `/readyz`.

### 5.7 Route returns 503

**Action:**

1. `oc get pods -n lab-hello` — pod must be Ready.
2. `oc get endpoints lab-hello -n lab-hello` — must list a pod IP.
3. Wait 30 seconds for the router, then retry `curl -k`.
4. Redeploy: `oc rollout restart deploy/lab-hello -n lab-hello`.

### 5.8 Cluster stuck, CRC reports Stopped or Error

```bash
crc stop
crc delete -f
crc setup
crc start
```

CRC clusters are disposable. Recreate rather than repair a corrupt VM.

## 6. Maintenance

| Task | Cadence | Command |
|---|---|---|
| Stop cluster when idle | Every session | `crc stop` |
| Upgrade CRC | When you install a new `crc` binary | `crc delete -f && crc setup && crc start` |
| Refresh pull secret | If builds fail auth | Re-download; `crc config set pull-secret-file` |
| Delete unused projects | When disk fills | `oc delete project <name>` |
| Full reset | After failed experiments | `crc delete -f` |

Disk pressure:

```bash
crc status
oc adm top nodes    # may be unavailable if metrics are off
```

If the CRC disk is full, delete the instance and recreate. Do not expect in-place disk repair.

## 7. Backup and data

There is **no backup design** for this lab.

- The CRC VM is ephemeral
- The test app is stateless
- Rebuild from this git repo + pull secret

Do not store unique data only inside the cluster.

## 8. Emergency stop

Host overloaded or fan-max:

```bash
crc stop
```

If the VM is wedged:

- Windows: stop the `crc` VM in Hyper-V Manager, then `crc delete -f`
- Linux: `sudo virsh destroy crc` then `crc delete -f`
- macOS: `crc delete -f`

Then `crc setup && crc start`.

## 9. Escalation (lab)

1. Capture `crc status` and the last 50 lines of `crc start` output.
2. `oc get nodes,co,pods -A`
3. Recreate the instance (`crc delete -f`).
4. If hardware is insufficient, switch to the `microshift` preset.
5. Official docs: [crc.dev](https://crc.dev/docs/getting-started/) and [OpenShift Local](https://console.redhat.com/openshift/create/local).
