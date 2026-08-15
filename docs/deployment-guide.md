# Deployment Guide

Step-by-step install of a **minimum-node OpenShift lab** on a 16 GB laptop, then deploy the smoke-test app.

## 1. Prerequisites

### Hardware

- 4 CPU cores, Intel/AMD with `VT-x` or `AMD-V` enabled in BIOS
- 16 GB RAM
- 50 GB free disk (35 GB cluster + bundle)

### Operating system

- Windows 10/11 **Pro** (Home is not supported)
- macOS 13 or later
- RHEL, Fedora, or recent Ubuntu/Debian

### Accounts and tools

- Free [Red Hat Developer](https://developers.redhat.com/) account
- [OpenShift Local download + pull secret](https://console.redhat.com/openshift/create/local)
- Git, a terminal, and a browser
- This repository cloned to the laptop

### Virtualization

Enable the **native** hypervisor. Do not install CRC inside VirtualBox.

| Host | Hypervisor |
|---|---|
| Windows | Hyper-V + Virtual Machine Platform |
| Linux | KVM + libvirt + NetworkManager |
| macOS | Built-in virtualization (vfkit) |

On Windows, stop VirtualBox VMs and prefer Hyper-V. Reboot after enabling Hyper-V.

Disconnect VPN before `crc start`.

## 2. Install OpenShift Local (`crc`)

### Windows / macOS

1. Run the guided installer from the Hybrid Cloud Console download.
2. Install to a local disk (`C:\` on Windows, not a network drive).
3. Reboot if the installer enabled Hyper-V.
4. Confirm:

```bash
crc version
```

### Linux

```bash
# Fedora / RHEL
sudo dnf install -y libvirt NetworkManager

# Ubuntu / Debian
sudo apt install -y qemu-kvm libvirt-daemon libvirt-daemon-system network-manager

cd ~/Downloads
tar xvf crc-linux-amd64.tar.xz
mkdir -p ~/bin
cp crc-linux-*-amd64/crc ~/bin/
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
crc version
```

Do not run `crc` as root or Administrator. Use a normal user that can sudo / elevate.

## 3. Configure the minimum cluster

Save the pull secret as `~/pull-secret.txt` (do not commit it).

```bash
crc config set preset openshift
crc config set cpus 4
crc config set memory 10752
crc config set disk-size 35
crc config set pull-secret-file ~/pull-secret.txt
crc config view
```

`10752` MiB is the OpenShift preset minimum. Leave the rest of the 16 GB for the host.

## 4. Create and start the cluster

```bash
crc setup
crc start
```

First start downloads the bundle and typically takes 15–30 minutes.

Success looks like:

- `CRC VM: Running`
- `OpenShift: Running`
- Console URL printed
- `kubeadmin` and `developer` passwords printed

Store those passwords. Retrieve later with:

```bash
crc console --credentials
```

## 5. Log in

```bash
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443
oc whoami
oc get nodes
```

You should see **one** Ready node.

Open the console:

```bash
crc console
```

Use `developer` for application work. Use `kubeadmin` only for cluster admin tasks.

## 6. Deploy the test app

From the repository root, after `oc` login:

```bash
chmod +x scripts/deploy.sh scripts/verify.sh
./scripts/deploy.sh
```

What the script does:

1. Creates project `lab-hello` if needed
2. Builds `app/` on-cluster with a Docker strategy BuildConfig
3. Applies Service, Route, and Deployment
4. Waits for the rollout

Manual equivalent:

```bash
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443
oc new-project lab-hello
oc new-app --name=lab-hello --strategy=docker ./app
oc logs -f bc/lab-hello
oc expose svc/lab-hello
oc rollout status deploy/lab-hello
```

If you already applied `manifests/route.yaml`, skip `oc expose`.

## 7. Verify

```bash
./scripts/verify.sh
```

Or by hand:

```bash
oc get pods,svc,route -n lab-hello
HOST=$(oc get route lab-hello -n lab-hello -o jsonpath='{.spec.host}')
curl -k "https://${HOST}/healthz"
curl -k "https://${HOST}/info"
```

Open `https://<host>` in a browser. You should see **OpenShift lab test app is running.**

## 8. Optional: run app unit tests on the laptop

Does not require the cluster.

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
pytest
```

## 9. If 10.5 GB is too heavy

```bash
crc delete -f
crc config set preset microshift
crc config set cpus 2
crc config set memory 4096
crc setup
crc start
```

MicroShift is a subset of OpenShift (no full web console). The same `oc` deploy path still works for the test app; skip `crc console`.

## 10. Fallback: one VirtualBox VM + MicroShift

Only if you cannot use CRC on the host.

1. Create **one** RHEL 9 VM: 4 vCPU, **8 GB RAM**, 50 GB disk, NAT or bridged. Nested VT-x off.
2. Register with a Developer subscription.
3. Enable MicroShift repos, install `microshift` and `openshift-clients`, start the service.
4. Copy `/var/lib/microshift/resources/kubeadmin/kubeconfig` to `~/.kube/config`.
5. Deploy with `oc` as in section 6 (create a Route or NodePort; MicroShift Route support depends on how ingress is installed).

See [MicroShift getting started](https://github.com/openshift/microshift/blob/main/docs/user/getting_started.md).

## 11. Tear down

```bash
oc delete project lab-hello
crc stop          # keep the VM for next session
crc delete -f     # destroy the cluster VM
```

## 12. Next

Use the [runbook](runbook.md) for daily start/stop, health checks, and common failures.
