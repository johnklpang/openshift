# Runbook

Operations for the Vagrant VirtualBox lab: **helper + 1 master + 3 workers**.

## 1. Roles

| Role | How you access it | Use |
|---|---|---|
| Host operator | laptop user | `vagrant up\|halt\|destroy` |
| Bastion | `vagrant ssh helper` | DNS, HAProxy, future `openshift-install` |
| Master | `vagrant ssh master` | Future control plane |
| Worker | `vagrant ssh worker1` (2, 3) | Future compute |

Default guest user: `vagrant` (sudo).

## 2. Daily operations

### Start

```bash
cd /path/to/openshift
./scripts/cluster-up.sh
# or: vagrant up
./scripts/cluster-status.sh
```

If the VMs already exist, `vagrant up` boots them and skips provision unless you pass `--provision`.

### Stop

```bash
./scripts/cluster-down.sh
# or: vagrant halt
```

Always halt when you are done. Five VMs will keep several GB of RAM reserved.

### Status

```bash
vagrant status
VBoxManage list runningvms
./scripts/cluster-status.sh
```

### SSH

```bash
vagrant ssh helper
vagrant ssh master
vagrant ssh worker1
```

From helper to a node (after you install an SSH key):

```bash
ssh vagrant@192.168.56.10
```

## 3. Health checks (prepared VMs)

| Check | Command | Expected |
|---|---|---|
| VM power | `vagrant status` | helper, master, worker1–3 `running` |
| Hostname | `vagrant ssh master -c 'hostname -f'` | `master.ocp.lab.local` |
| Swap | `vagrant ssh master -c 'swapon --show'` | empty |
| Marker | `cat /etc/ocp-lab/node.env` | `ROLE=master` (or worker/helper) |
| Hosts | `getent hosts api.ocp.lab.local` | `192.168.56.9` |
| HAProxy | `vagrant ssh helper -c 'systemctl is-active haproxy'` | `active` |
| DNS | `vagrant ssh helper -c 'systemctl is-active dnsmasq'` | `active` |
| HTTP | `curl -s http://192.168.56.9/` | helper index page |

HAProxy backends for 6443/80/443 stay **DOWN** until OpenShift is installed. That is normal in the prepare phase.

## 4. Common incidents

### 4.1 `vagrant up` — VT-x / AMD-V is not available

**Action:** Enable virtualization in BIOS. On Windows, turn **off** Hyper-V, Memory Integrity, and Windows Hypervisor Platform, then reboot. VirtualBox and Hyper-V cannot both own the CPU.

### 4.2 Host-only network / `192.168.56.x` not created

**Action:**

```bash
VBoxManage list hostonlyifs
```

Create the default adapter in VirtualBox: **File → Tools → Network Manager → Host-only**. Use `192.168.56.1/24` (or `/21` on VirtualBox 7). Re-run `vagrant up`.

### 4.3 Box download fails or is slow

**Action:** Retry `vagrant box add bento/rockylinux-9 --provider virtualbox`. Confirm disk space. Set `VAGRANT_EXPERIMENTAL` is not required.

### 4.4 Provision fails on `dnf`

**Action:** The NAT NIC needs outbound HTTPS. Disconnect VPN. `vagrant ssh <node>` then `curl -I https://mirrors.rockylinux.org`. Re-run:

```bash
vagrant provision master
```

### 4.5 Guest additions / synced folder errors

The Vagrantfile disables `/vagrant`. Ignore leftover Guest Additions warnings if provision finished and `/etc/ocp-lab/node.env` exists.

### 4.6 Laptop swap / freeze after `vagrant up`

You are on the 16 GB `prep` profile and still overcommitted.

```bash
vagrant halt worker3 worker2
```

Keep helper + master + one worker for inspection. Do **not** switch to `LAB_PROFILE=install` on 16 GB.

### 4.7 dnsmasq or haproxy will not start on helper

```bash
vagrant ssh helper
sudo systemctl status dnsmasq haproxy --no-pager
sudo journalctl -u dnsmasq -u haproxy -e --no-pager
sudo dnsmasq --test
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Re-copy configs:

```bash
vagrant provision helper
```

### 4.8 Clock skew

```bash
vagrant ssh master -c 'timedatectl'
sudo systemctl restart chronyd
```

OpenShift install will fail if node time is far off.

### 4.9 Need a clean rebuild

```bash
./scripts/cluster-down.sh destroy
./scripts/cluster-up.sh
```

## 5. Maintenance

| Task | Command |
|---|---|
| Re-run node prep | `vagrant provision` |
| Re-run one node | `vagrant provision worker2` |
| Resize not supported in place | destroy and change `LAB_PROFILE` |
| Update box | `vagrant box update` then destroy/up |
| Free host RAM | `vagrant halt` |

Change profile (destroys current sizes):

```bash
vagrant destroy -f
LAB_PROFILE=install vagrant up
```

## 6. Emergency stop

Host overloaded:

```bash
vagrant halt
```

If Vagrant cannot talk to VirtualBox:

```bash
VBoxManage list runningvms
VBoxManage controlvm ocp-master poweroff
VBoxManage controlvm ocp-worker1 poweroff
VBoxManage controlvm ocp-worker2 poweroff
VBoxManage controlvm ocp-worker3 poweroff
VBoxManage controlvm ocp-helper poweroff
```

Then `vagrant destroy -f` if the lab is corrupt.

## 7. Backup and data

No backup. Boxes and provision scripts in git are the source of truth. Treat VMs as disposable.

## 8. Escalation (lab)

1. Capture `vagrant status` and the failing provision log.
2. `VBoxManage list vms` and `VBoxManage list hostonlyifs`.
3. Destroy and recreate.
4. If you need a working OpenShift API on 16 GB, use CRC (deployment guide appendix A).
5. Docs: [Vagrant](https://developer.hashicorp.com/vagrant/docs), [VirtualBox](https://www.virtualbox.org/manual/), [OpenShift UPI](https://docs.redhat.com/en/documentation/openshift_container_platform/).
