---
type: runbook
title: NVIDIA GPU Passthrough Setup for Proxmox VMs
category: infrastructure
status: active
tested: 2025-11-01
hardware: NVIDIA RTX 4060 Ti
proxmox-version: 8.x
vm-os: Ubuntu 24.04
created: 2025-11-01
updated: 2025-11-01
tags:
  - runbook
  - proxmox
  - gpu
  - passthrough
  - nvidia
  - docker
  - automation
---

# NVIDIA GPU Passthrough Setup for Proxmox VMs

> **Purpose:** Step-by-step guide to pass through an NVIDIA GPU from Proxmox host to a VM for hardware-accelerated workloads (transcoding, AI, etc.)
>
> **Tested:** 2025-11-01 with NVIDIA RTX 4060 Ti → VM 100 (Emby) on Proxmox VE 8.x
>
> **Automation Goal:** This runbook is designed to be scripted for repeatable, automated GPU passthrough setup on new VMs.

## Overview

This runbook documents the complete process of configuring NVIDIA GPU passthrough from a Proxmox host to a guest VM, including:
1. Proxmox host configuration (IOMMU, VFIO, driver blacklist)
2. VM configuration (machine type, BIOS, PCI devices)
3. Guest OS configuration (drivers, Docker nvidia runtime)
4. Validation and troubleshooting

**Prerequisites:**
- Proxmox VE 8.x host with NVIDIA GPU
- VM created from base template (Ubuntu 24.04)
- SSH access to Proxmox host and VM
- GPU in isolated IOMMU group (verify with research first)

**Time Estimate:** 2-3 hours (including testing and troubleshooting)

---

## Phase 0: Pre-Flight Checks and Research

### 0.1 Verify GPU IOMMU Isolation

**On Proxmox host:**

```bash
# Check IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -i nvidia
```

**Expected output:**
```
IOMMU Group 12 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106 [GeForce RTX 4060 Ti] [10de:2803] (rev a1)
IOMMU Group 12 01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22bd] (rev a1)
```

**✅ Good:** GPU and audio in same IOMMU group, no other devices
**❌ Bad:** GPU grouped with other critical devices (USB, network, storage)

**Record these values:**
- `IOMMU Group`: 12
- `PCI Address (GPU)`: 01:00.0
- `PCI Address (Audio)`: 01:00.1
- `Vendor:Device (GPU)`: 10de:2803
- `Vendor:Device (Audio)`: 10de:22bd

### 0.2 Identify Target VM

**VM Details:**
- VM ID: 100
- VM Name: ininity-node-emby
- Current IP: 192.168.1.100
- OS: Ubuntu 24.04 LTS
- Purpose: Emby media server with hardware transcoding

### 0.3 Capture Baseline Performance (Optional but Recommended)

If the VM already has the workload running (e.g., Emby), capture baseline CPU-only performance for comparison.

**For Emby transcoding:**
```bash
# SSH to VM
ssh evan@192.168.1.100

# Start a test transcode and monitor
docker logs -f emby

# Note the "speed=X.Xx" values in transcode logs
# CPU-only typically: 0.5-0.7x for 4K, 1-2x for 1080p
```

**Document baseline:**
- 1080p transcode speed: ~0.5-0.7x realtime
- 4K transcode speed: <1x realtime
- CPU usage during transcode: 60-80%

### 0.4 Create VM Snapshot

⚠️ **CRITICAL:** Create a snapshot before making any changes for easy rollback.

**On Proxmox host:**
```bash
qm snapshot 100 before-gpu-passthrough --description "Pre-GPU passthrough snapshot"
```

**Verify snapshot created:**
```bash
qm listsnapshot 100
```

---

## Phase 1: Configure Proxmox Host for GPU Passthrough

All commands in this phase run on the **Proxmox host** as **root**.

### 1.1 Enable IOMMU in Kernel

**Edit GRUB configuration:**
```bash
nano /etc/default/grub
```

**Find the line starting with `GRUB_CMDLINE_LINUX_DEFAULT` and modify:**

**For Intel CPU:**
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**For AMD CPU:**
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

**Save and exit** (`Ctrl+X`, `Y`, `Enter`)

**Update GRUB:**
```bash
update-grub
```

**Expected output:**
```
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.x.x
Found initrd image: /boot/initrd.img-6.x.x
done
```

### 1.2 Load VFIO Kernel Modules at Boot

**Edit modules file:**
```bash
nano /etc/modules
```

**Add these lines at the end:**
```
# VFIO modules for GPU passthrough (IN-032)
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**Save and exit**

### 1.3 Blacklist NVIDIA Drivers on Proxmox Host

This prevents the Proxmox host from using the GPU, reserving it for VM passthrough.

**Create blacklist file:**
```bash
nano /etc/modprobe.d/blacklist-nvidia.conf
```

**Add these lines:**
```
# Blacklist NVIDIA drivers on host for GPU passthrough (IN-032)
# Prevents Proxmox from using the GPU, reserving it for VM passthrough
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

**Save and exit**

### 1.4 Bind GPU to VFIO-PCI Driver

This tells the kernel to use VFIO drivers for the GPU instead of NVIDIA drivers.

**Create VFIO configuration:**
```bash
nano /etc/modprobe.d/vfio.conf
```

**Add this line (replace with your GPU vendor:device IDs from Phase 0.1):**
```
# Bind NVIDIA RTX 4060 Ti to vfio-pci for VM passthrough (IN-032)
# GPU: 10de:2803, Audio: 10de:22bd
options vfio-pci ids=10de:2803,10de:22bd
```

**Save and exit**

### 1.5 Update Initramfs

**Rebuild initramfs with new configuration:**
```bash
update-initramfs -u -k all
```

**Expected output:**
```
update-initramfs: Generating /boot/initrd.img-6.x.x
```

### 1.6 Reboot Proxmox Host

⚠️ **This will cause downtime for ALL VMs on the host!**

```bash
reboot
```

**Wait 2-3 minutes for Proxmox to reboot**

### 1.7 Verify VFIO Configuration

**After Proxmox reboots, SSH back in and verify:**

```bash
# Verify IOMMU is enabled
dmesg | grep -e DMAR -e IOMMU

# Expected output includes:
# DMAR: IOMMU enabled
# or
# AMD-Vi: AMD IOMMUv2 loaded and initialized
```

```bash
# Verify VFIO modules loaded
lsmod | grep vfio

# Expected output:
# vfio_pci
# vfio_iommu_type1
# vfio
```

```bash
# Verify GPU bound to vfio-pci driver
lspci -nnk -d 10de:2803

# Expected output should show:
# Kernel driver in use: vfio-pci
```

**✅ If all checks pass:** Proxmox host is configured correctly
**❌ If any fail:** Review configuration files and reboot again

---

## Phase 2: Configure VM for GPU Passthrough

All commands in this phase run on the **Proxmox host** as **root**.

### 2.1 Stop the Target VM

```bash
qm stop 100
```

**Wait for VM to fully stop:**
```bash
qm status 100
# Should show: status: stopped
```

### 2.2 Configure VM Machine Type

The VM needs Q35 machine type for proper PCIe passthrough support.

**Edit VM configuration:**
```bash
qm set 100 --machine q35
```

**Verify:**
```bash
qm config 100 | grep machine
# Expected: machine: q35
```

### 2.3 Keep BIOS as SeaBIOS (NOT OVMF)

⚠️ **CRITICAL LESSON LEARNED:** If your VM OS is already installed with legacy BIOS, do NOT switch to OVMF/UEFI. The OS won't boot.

**Check current BIOS:**
```bash
qm config 100 | grep bios
# If empty or "seabios", you're good
# If "ovmf", and OS was installed with legacy BIOS, revert it
```

**If you accidentally set OVMF and VM won't boot:**
```bash
qm set 100 --bios seabios
```

**Our tested configuration:**
- **Machine type:** Q35
- **BIOS:** SeaBIOS (default)
- **This combination works!**

### 2.4 Add PCI Passthrough Devices

**Add GPU (video controller):**
```bash
qm set 100 --hostpci0 01:00.0,pcie=1
```

**Add GPU audio device:**
```bash
qm set 100 --hostpci1 01:00.1,pcie=1
```

**Verify PCI devices added:**
```bash
qm config 100 | grep hostpci

# Expected output:
# hostpci0: 0000:01:00.0,pcie=1
# hostpci1: 0000:01:00.1,pcie=1
```

**Parameter explanation:**
- `01:00.0` - PCI address of GPU (from Phase 0.1)
- `pcie=1` - Enable PCIe passthrough (required for Q35)

### 2.5 Start the VM

```bash
qm start 100
```

**Monitor startup:**
```bash
qm status 100
# Wait for: status: running
```

**Check VM console for boot messages:**
```bash
# Via Proxmox UI: VM 100 → Console
# Or via command line:
qm terminal 100
```

---

## Phase 2.6: CRITICAL - Network Interface Name Change

⚠️ **KNOWN ISSUE:** When changing from `i440fx` (default) to `Q35` machine type, **the network interface name WILL change**.

**What happens:**
- Old interface: `ens18`
- New interface: `enp6s18` (or similar, depends on PCI slot)

**Symptoms:**
- VM boots but has no network connectivity
- Cannot SSH to VM
- IP address not assigned

### 2.6.1 Diagnose Network Issue

**From Proxmox console (VM 100 → Console):**

```bash
# Check network interfaces
ip addr show

# Old interface (ens18) will show: NO-CARRIER, state DOWN
# New interface (enp6s18) will show: state DOWN, no IP
```

**Expected output:**
```
2: ens18: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 state DOWN
3: enp6s18: <BROADCAST,MULTICAST> mtu 1500 state DOWN
```

### 2.6.2 Fix Network Configuration

**Option A: Quick Fix (Temporary - for initial access)**

From Proxmox console:

```bash
# Bring up new interface
sudo ip link set enp6s18 up

# Restart networking
sudo systemctl restart systemd-networkd

# Manually assign IP (replace with your VM's IP)
sudo ip addr add 192.168.1.100/24 dev enp6s18
sudo ip route add default via 192.168.1.1

# Test connectivity
ping -c 3 8.8.8.8
```

**Option B: Permanent Fix (Update Netplan)**

From Proxmox console:

```bash
# Edit netplan configuration
sudo nano /etc/netplan/50-cloud-init.yaml
```

**Change `ens18` to `enp6s18`:**

```yaml
network:
    ethernets:
        enp6s18:  # Changed from ens18
            addresses:
              - 192.168.1.100/24
            routes:
              - to: default
                via: 192.168.1.1
            nameservers:
              addresses:
                - 192.168.1.1
                - 8.8.8.8
    version: 2
```

**Apply configuration:**
```bash
sudo netplan apply
```

**Verify network is up:**
```bash
ip addr show enp6s18
# Should show: state UP and inet 192.168.1.100/24

ping -c 3 8.8.8.8
# Should succeed
```

**Now you can SSH to the VM:**
```bash
ssh evan@192.168.1.100
```

### 2.7 Verify GPU Visible in VM

**SSH to VM:**
```bash
ssh evan@192.168.1.100
```

**Check if GPU is visible:**
```bash
lspci | grep -i nvidia
```

**Expected output:**
```
01:00.0 VGA compatible controller: NVIDIA Corporation AD106 [GeForce RTX 4060 Ti] (rev a1)
01:00.1 Audio device: NVIDIA Corporation Device 22bd (rev a1)
```

**✅ If GPU is visible:** Phase 2 complete!
**❌ If GPU not visible:** Check Proxmox configuration and restart VM

---

## Phase 3: Install NVIDIA Drivers in VM

All commands in this phase run **inside the VM** as user with sudo access.

### 3.1 Update Package List

```bash
sudo apt update
```

### 3.2 Install ubuntu-drivers-common

```bash
sudo apt install -y ubuntu-drivers-common
```

### 3.3 Detect Available NVIDIA Drivers

```bash
sudo ubuntu-drivers devices
```

**Expected output:**
```
== /sys/devices/pci0000:00/0000:00:1c.0/0000:01:00.0 ==
modalias : pci:v000010DEd00002803...
vendor   : NVIDIA Corporation
model    : AD106 [GeForce RTX 4060 Ti]
driver   : nvidia-driver-580-open - distro non-free recommended
driver   : nvidia-driver-580 - distro non-free
driver   : nvidia-driver-570 - distro non-free
...
```

**Note the recommended driver** (e.g., `nvidia-driver-580-open`)

### 3.4 Install NVIDIA Drivers

**Option A: Install recommended driver automatically (RECOMMENDED)**

```bash
sudo ubuntu-drivers autoinstall
```

**Option B: Install specific driver manually**

```bash
sudo apt install -y nvidia-driver-580-open
```

**Installation will take 5-10 minutes** and download ~500MB of packages.

**Expected output includes:**
- New kernel modules installed
- `linux-modules-nvidia-580-open-6.8.0-XX-generic` package
- Kernel update to match driver version

### 3.5 Reboot VM to Load Drivers

```bash
sudo reboot
```

**Wait 1-2 minutes for VM to reboot**

### 3.6 Verify NVIDIA Drivers Loaded

**SSH back to VM:**
```bash
ssh evan@192.168.1.100
```

**Run nvidia-smi:**
```bash
nvidia-smi
```

**Expected output:**
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.95.05              Driver Version: 580.95.05      CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 4060 Ti     Off |   00000000:01:00.0 Off |                  N/A |
| 30%   42C    P8              4W /  160W |      34MiB /   8188MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```

**✅ GPU detected with driver loaded:** Phase 3 complete!
**❌ nvidia-smi fails:** Check driver installation and kernel modules

---

## Phase 4: Configure Docker nvidia-container-toolkit

All commands in this phase run **inside the VM**.

### 4.1 Add NVIDIA Container Toolkit Repository

```bash
# Add GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Add repository
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

### 4.2 Install nvidia-container-toolkit

```bash
sudo apt update
sudo apt install -y nvidia-container-toolkit
```

**Installation takes ~1 minute**

### 4.3 Configure Docker to Use NVIDIA Runtime

```bash
sudo nvidia-ctk runtime configure --runtime=docker
```

**Expected output:**
```
INFO[0000] Loading config from /etc/docker/daemon.json
INFO[0000] Wrote updated config to /etc/docker/daemon.json
INFO[0000] It is recommended that docker daemon be restarted.
```

### 4.4 Restart Docker Daemon

```bash
sudo systemctl restart docker
```

**Verify Docker is running:**
```bash
sudo systemctl status docker
# Should show: active (running)
```

### 4.5 Verify Docker Can Access GPU

**Run a test container:**
```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

**Expected output:** Same nvidia-smi output as before, but from inside the container.

**✅ nvidia-smi works in container:** Phase 4 complete!
**❌ Error:** Check nvidia-container-toolkit installation and Docker configuration

---

## Phase 5: Configure Application for GPU (Emby Example)

This phase is application-specific. Here's the example for Emby.

### 5.1 Update docker-compose.yml

**Edit the application's docker-compose file:**
```bash
cd /path/to/app
nano docker-compose.yml
```

**Add GPU configuration to the service:**
```yaml
services:
  embyserver:
    # ... existing configuration ...

    # Add GPU support
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities:
                - gpu
```

**Save the file**

### 5.2 Commit Configuration to Git

```bash
git add docker-compose.yml
git commit -m "feat: enable GPU support for hardware acceleration"
```

### 5.3 Deploy via Portainer

**Option A: Portainer UI**
1. Login to Portainer
2. Navigate to Stacks → [stack-name]
3. Click "Pull and redeploy"

**Option B: Portainer API Script**
```bash
# If you have a redeploy script
./scripts/infrastructure/redeploy-git-stack.sh \
  --secret "portainer-api-token-vm-XXX" \
  --stack-name "emby"
```

### 5.4 Verify GPU Devices in Container

```bash
# Check if NVIDIA devices are mounted
docker exec [container-name] ls -la /dev | grep nvidia
```

**Expected output:**
```
crw-rw-rw-    1 root     root      235,   0 Oct 31 22:58 nvidia-uvm
crw-rw-rw-    1 root     root      235,   1 Oct 31 22:58 nvidia-uvm-tools
crw-rw-rw-    1 root     root      195,   0 Oct 31 22:58 nvidia0
crw-rw-rw-    1 root     root      195, 255 Oct 31 22:58 nvidiactl
```

**✅ NVIDIA devices present:** Application can access GPU!

### 5.5 Configure Application to Use GPU

**For Emby:**
1. Access Emby web UI: `http://emby.local.infinity-node.win` (port-free) or `http://emby.local.infinity-node.win:8096` (direct)
2. Navigate to **Settings → Transcoding**
3. Hardware acceleration: Select **NVIDIA NVENC**
4. Enable hardware decoding for: H.264, HEVC
5. Enable hardware encoding for: H.264, HEVC
6. Save settings

**For other applications:** Consult application-specific documentation.

---

## Phase 6: Validation and Performance Testing

### 6.1 Test GPU Transcoding (Emby Example)

**Start playing a video that requires transcoding:**
- In Emby, play any video
- Set quality to lower than source (forces transcode)

**Monitor GPU usage:**
```bash
# Real-time monitoring
watch -n 1 nvidia-smi

# Or
nvidia-smi dmon -s u
```

**Expected output during transcode:**
```
# gpu     sm    mem    enc    dec    jpg    ofa
# Idx      %      %      %      %      %      %
    0      8     11     63     25      0      0
```

**Key metrics:**
- `enc` (encoder): Should be 60-88% during active transcode
- `dec` (decoder): Should be 20-35% if hardware decode enabled
- `sm` (shader cores): Should be 5-15%

### 6.2 Check Application Logs

**For Emby transcoding:**
```bash
docker exec emby sh -c 'ls -t /config/logs/ffmpeg-transcode-*.txt | head -1 | xargs tail -20'
```

**Look for:**
- `speed=X.Xx` - Transcode speed multiplier (should be >2x for 1080p, >1.5x for 4K)
- `fps=XX` - Frames per second being transcoded

**Example output:**
```
elapsed=00:00:29.94 frame= 2939 fps= 98 speed=4.08x
```

**✅ speed=4.08x:** Transcoding at 4x realtime (excellent!)

### 6.3 Compare to Baseline

**Measure performance improvement:**

| Metric | CPU Baseline | GPU (After) | Improvement |
|--------|--------------|-------------|-------------|
| 1080p transcode | 0.5-0.7x | 4.08x | 6-8x faster |
| 4K transcode | <1x | 3.86x | 4-6x faster |
| CPU usage | 60-80% | <10% | 90%+ reduction |
| Power draw | ~150W | ~40W | 70% less |

### 6.4 Stress Test (Multiple Streams)

**Start 2-3 simultaneous transcodes:**
- Open Emby in multiple browsers/tabs
- Start playback on each with different quality settings

**Monitor GPU:**
```bash
nvidia-smi dmon -c 30 -s u
```

**Check for:**
- Encoder utilization should stay under 90%
- Memory usage should stay under 80%
- No dropped frames or playback issues

**✅ All streams smooth:** GPU has sufficient capacity

---

## Troubleshooting Guide

### Issue: VM Won't Boot After Q35 Change

**Symptoms:**
- Black screen or "No bootable device" message
- VM stuck at boot

**Cause:** OS was installed with legacy BIOS, switched to UEFI (OVMF)

**Solution:**
```bash
# On Proxmox host
qm set 100 --bios seabios
qm start 100
```

### Issue: No Network After Q35 Change

**Symptoms:**
- Cannot SSH to VM
- VM has no IP address
- Old interface shows NO-CARRIER

**Cause:** Network interface name changed (ens18 → enp6s18)

**Solution:** See Phase 2.6 for detailed fix

**Quick fix from console:**
```bash
sudo ip link set enp6s18 up
sudo ip addr add 192.168.1.100/24 dev enp6s18
sudo ip route add default via 192.168.1.1
```

### Issue: GPU Not Visible in VM

**Symptoms:**
- `lspci | grep NVIDIA` shows nothing

**Diagnosis:**
```bash
# On Proxmox host
qm config 100 | grep hostpci
# Should show hostpci0 and hostpci1

# Check VM is running
qm status 100

# Check Proxmox logs
journalctl -u pve-cluster -f
```

**Solutions:**
1. Verify IOMMU enabled on host: `dmesg | grep IOMMU`
2. Verify VFIO binding: `lspci -nnk -d 10de:2803`
3. Restart VM: `qm stop 100 && qm start 100`
4. Check PCI addresses match: Compare `lspci` on host vs `qm config`

### Issue: nvidia-smi Not Found or Fails

**Symptoms:**
- `nvidia-smi` command not found
- `nvidia-smi` shows "No devices found"

**Diagnosis:**
```bash
# Check driver installed
dpkg -l | grep nvidia

# Check kernel modules loaded
lsmod | grep nvidia

# Check device permissions
ls -la /dev/nvidia*
```

**Solutions:**
1. Reinstall drivers: `sudo ubuntu-drivers autoinstall`
2. Reboot VM
3. Check kernel version matches driver: `uname -r`
4. Load modules manually: `sudo modprobe nvidia`

### Issue: Docker Can't Access GPU

**Symptoms:**
- `docker run --gpus all` fails with "could not select device driver"
- No GPU devices in container

**Diagnosis:**
```bash
# Check nvidia-container-toolkit installed
dpkg -l | grep nvidia-container-toolkit

# Check Docker daemon config
cat /etc/docker/daemon.json
```

**Solutions:**
1. Reinstall toolkit: `sudo apt install --reinstall nvidia-container-toolkit`
2. Reconfigure Docker: `sudo nvidia-ctk runtime configure --runtime=docker`
3. Restart Docker: `sudo systemctl restart docker`
4. Check Docker logs: `sudo journalctl -u docker -f`

### Issue: Poor Transcode Performance

**Symptoms:**
- Transcode speed <1.5x
- GPU encoder showing low utilization (<30%)
- Buffering during playback

**Diagnosis:**
```bash
# Check GPU usage during transcode
nvidia-smi dmon -s u

# Check transcode logs for CPU encoding
docker exec emby grep -i "h264_nvenc\|hevc_nvenc" /config/logs/ffmpeg-transcode-*.txt
```

**Solutions:**
1. Verify hardware encoding enabled in application UI
2. Check transcode logs for software encoding fallback
3. Restart application container
4. Check for codec support (some codecs may not support hardware encoding)

### Issue: IP Address Keeps Changing

**Symptoms:**
- VM gets different IP on each boot
- DHCP assigns new IP randomly

**Cause:** Static IP not configured in netplan

**Solution:**
Edit `/etc/netplan/50-cloud-init.yaml`:
```yaml
network:
    ethernets:
        enp6s18:
            addresses:
              - 192.168.1.100/24  # Static IP
            routes:
              - to: default
                via: 192.168.1.1
            nameservers:
              addresses:
                - 192.168.1.1
                - 8.8.8.8
    version: 2
```

Apply: `sudo netplan apply`

---

## Automation Considerations

### Variables to Parameterize

For scripting this process, parameterize:

```bash
# Proxmox host
PROXMOX_HOST="192.168.1.81"
GPU_PCI_ADDRESS="01:00.0"
GPU_AUDIO_PCI_ADDRESS="01:00.1"
GPU_VENDOR_DEVICE="10de:2803"
GPU_AUDIO_VENDOR_DEVICE="10de:22bd"
IOMMU_GROUP="12"

# Target VM
VM_ID="100"
VM_NAME="ininity-node-emby"
VM_IP="192.168.1.100"
VM_GATEWAY="192.168.1.1"
VM_USER="evan"

# Network interface (will change with Q35!)
OLD_INTERFACE="ens18"
NEW_INTERFACE="enp6s18"

# NVIDIA driver
NVIDIA_DRIVER="nvidia-driver-580-open"

# Application
APP_NAME="emby"
APP_STACK_PATH="/path/to/stacks/emby"
```

### Script Phases

**Phase 1: Proxmox Host Configuration**
- Can be automated completely
- Requires root SSH access to Proxmox
- Requires host reboot (coordinate downtime)

**Phase 2: VM Configuration**
- Can be automated with `qm` commands
- Network fix needs handling (detect new interface name)
- May need retry logic for network coming up

**Phase 3: Driver Installation**
- Can be automated with `ubuntu-drivers autoinstall`
- Requires VM reboot
- Should verify with `nvidia-smi` before proceeding

**Phase 4: Docker Configuration**
- Fully automatable
- Script should test with container before proceeding

**Phase 5: Application Configuration**
- Git operations automatable
- Portainer deployment automatable (API or UI)
- Application-specific UI configuration may need manual step

### Validation Checks

**Script should validate:**
1. ✅ IOMMU enabled on host
2. ✅ GPU in isolated IOMMU group
3. ✅ VFIO modules loaded
4. ✅ GPU bound to vfio-pci
5. ✅ VM has GPU visible
6. ✅ nvidia-smi works in VM
7. ✅ Docker can access GPU
8. ✅ GPU devices in container
9. ✅ Application using GPU (transcode speed check)

### Rollback Strategy

**Automated rollback should:**
1. Restore VM from snapshot if GPU not visible
2. Revert Proxmox host configuration if VFIO fails
3. Restore application compose if deployment fails
4. Provide clear error messages with troubleshooting steps

### Testing the Automation

**Test plan:**
1. Create fresh VM from template
2. Run automation script
3. Verify all validation checks pass
4. Test application workload (transcode)
5. Reboot VM and host, verify persistence
6. Test rollback procedures

---

## Performance Benchmarks

**Tested configuration:**
- **GPU:** NVIDIA GeForce RTX 4060 Ti (8GB)
- **Driver:** 580.95.05 (open-source)
- **VM:** Ubuntu 24.04, 6.8.0-87-generic kernel
- **Application:** Emby 4.x with NVENC
- **Workload:** Mixed 1080p and 4K HEVC video transcoding

**Results:**

| Test | Metric | Value |
|------|--------|-------|
| 1080p H.264 transcode | Speed | 4.08x realtime |
| 1080p H.264 transcode | FPS | 98 fps |
| 1080p H.264 transcode | GPU Encoder | 60-72% |
| 4K HEVC transcode | Speed | 3.86x realtime |
| 4K HEVC transcode | GPU Encoder | 70-88% |
| Idle GPU power | Power | 4W |
| Active transcode power | Power | 40-48W |
| CPU usage (during transcode) | CPU % | <10% |
| Multiple streams (3x 1080p) | GPU Encoder | 85-90% |
| Memory usage per stream | VRAM | 540-850 MiB |

**Comparison to CPU baseline:**
- 6-8x faster transcode speed
- 90%+ CPU usage reduction
- 70% power consumption reduction
- 3-5x concurrent stream capacity

---

## References

**Documentation:**
- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [NVIDIA Container Toolkit Docs](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Emby Hardware Acceleration](https://support.emby.media/support/solutions/articles/44001159092)

**Related Tasks:**
- [[tasks/completed/IN-032-implement-emby-gpu-passthrough|IN-032]] - Implementation log
- [[tasks/completed/IN-007-research-emby-transcoding-optimization|IN-007]] - Research phase
- [[docs/research/proxmox-nvidia-gpu-passthrough-configuration|GPU Passthrough Research]] - Technical details

**Related ADRs:**
- [[docs/adr/013-emby-transcoding-optimization|ADR-013]] - Transcoding optimization strategy

---

## Changelog

### 2025-11-01
- Initial runbook created from IN-032 implementation
- Documented complete process for NVIDIA RTX 4060 Ti passthrough
- Added network interface change gotcha (Q35 machine type)
- Documented BIOS compatibility issues (SeaBIOS vs OVMF)
- Added automation considerations and parameterization
- Included performance benchmarks and validation checks
