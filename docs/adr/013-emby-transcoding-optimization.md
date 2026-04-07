---
type: adr
number: 013
title: Emby Transcoding Optimization Strategy
date: 2025-10-31
status: proposed
deciders:
  - Evan
tags:
  - adr
  - emby
  - transcoding
  - performance
  - hardware-acceleration
  - gpu
related-tasks:
  - IN-007
---

# ADR-013: Emby Transcoding Optimization Strategy

**Date:** 2025-10-31
**Status:** Proposed (Research Phase)
**Deciders:** Evan
**Related:** [[tasks/current/IN-007-research-emby-transcoding-optimization|IN-007]]

## Context

Emby media server (VM 100) performs video transcoding for:
- Format conversion for client compatibility
- Quality/bitrate adjustment for bandwidth constraints
- Subtitle burning when required
- HDR to SDR tone mapping

**Current State:**
- Transcoding performed via **CPU only** (software encoding)
- AMD Ryzen 7 7700 (8C/16T) - powerful but inefficient for transcoding
- High CPU usage during transcodes (can impact other services)
- High power consumption during sustained transcoding
- Slower transcode speeds (typically 1-3x playback speed)

**Problem:**
- Transcoding is resource-intensive and inefficient
- Household users experience occasional buffering during transcodes
- High CPU usage affects VM 102 (arr services) on same host
- Opportunity for significant performance improvement with hardware acceleration

**Research Conducted:**
- Hardware capabilities audit (Phase 2 of IN-007)
- IOMMU and GPU passthrough feasibility assessment
- Review of available hardware transcoding options
- Analysis of previous GPU passthrough attempts

## Hardware Findings

**CPU:** AMD Ryzen 7 7700 (8-core, 16-thread, 3.8GHz)
- ❌ **Intel QuickSync:** Not available (AMD CPU, Intel-only feature)
- ✅ **Software transcoding:** Capable but inefficient

**GPUs Available:**
1. **NVIDIA GeForce RTX 4060 Ti** (PCI 01:00.0)
   - 8th generation NVENC encoder (Ada Lovelace architecture)
   - Supports H.264, HEVC, AV1 hardware encoding
   - Up to 8K resolution support
   - Very power efficient
   - **IOMMU Status:** ✅ **Perfect isolation** (IOMMU Group 12: GPU + audio only)
   - **Passthrough Feasibility:** ✅ Excellent (clean IOMMU group, modern GPU)

2. **AMD Raphael iGPU** (PCI 13:00.0)
   - Integrated graphics in Ryzen 7 7700
   - AMD VCE hardware encoder
   - Supports H.264 and HEVC
   - **IOMMU Status:** ⚠️ Complex (multiple devices in groups 29-34)
   - **Passthrough Feasibility:** ⚠️ Possible but complex

**IOMMU:** ✅ Enabled (AMD-Vi active)

**Previous GPU Passthrough History:**
- User attempted GPU passthrough in the past but encountered issues
- Specific failure details not recalled (was some time ago)
- Likely configuration/knowledge issues, not hardware limitations
- May have used different GPU or outdated guides

**Emby Premiere License:**
- ✅ **Already available** (user confirmed)
- Hardware transcoding requires Emby Premiere subscription
- No additional licensing cost needed
- Ready to enable hardware transcoding immediately

## Decision

Implement a **two-phase optimization strategy**:

### Phase 1: tmpfs for Transcode Cache (Low-Risk Quick Win)
**Status:** Implement first
**Risk:** Very Low
**Complexity:** Low (Docker Compose change only)

Mount a tmpfs (RAM-based filesystem) for Emby's transcode directory:
- Eliminates disk I/O bottleneck for temporary transcode files
- Faster read/write speeds (RAM vs disk)
- Reduces wear on storage
- Easy to implement and test
- Easy to rollback if issues occur
- Benefit: 10-30% faster transcode start and processing

**Implementation:**
- Add tmpfs mount to Emby docker-compose: `/transcode` → tmpfs (4-8GB)
- No configuration changes in Emby itself
- Test with typical transcode workload
- Monitor memory usage to ensure adequate RAM available

### Phase 2: NVIDIA GPU Passthrough (High-Impact, Higher-Risk)
**Status:** Pursue after tmpfs validation
**Risk:** Medium (can rollback via VM snapshot)
**Complexity:** Medium (standard GPU passthrough, well-documented)

Pass through NVIDIA RTX 4060 Ti to VM 100 for hardware transcoding:
- Configure Proxmox for GPU passthrough (vfio-pci, IOMMU settings)
- Pass through PCI device 01:00.0 (GPU) and 01:00.1 (audio) to VM 100
- Install NVIDIA drivers in VM
- Configure Docker for nvidia-docker runtime
- Update Emby docker-compose for GPU access
- Configure Emby to use NVENC hardware encoding

**Expected Benefits:**
- **10-20x faster transcoding** (vs CPU-only)
- **Massive CPU usage reduction** (90%+ less CPU during transcodes)
- **Lower power consumption** (NVENC much more efficient than CPU)
- **Better multi-stream performance** (can handle multiple concurrent transcodes)
- **Improved user experience** (instant playback, no buffering)

**Prerequisites:**
- ✅ **Emby Premiere license:** Already available (confirmed)
- No additional licensing cost or barriers

**Risk Mitigation:**
- VM snapshot exists (`emby-research-backup`) for instant rollback
- Test during low-usage window (3-6 AM)
- Progressive testing: drivers → Docker → Emby
- Fallback plan: rollback snapshot, revert to CPU transcoding

## Consequences

### Phase 1: tmpfs (Positive Only)
✅ **Positive:**
- Faster transcode starts (eliminates disk I/O wait)
- Reduced disk wear on SSD/NAS storage
- 10-30% faster processing for temp file operations
- Very low risk (easy rollback)
- Free (uses existing RAM)
- No changes to Emby configuration
- Easy to implement (Docker Compose only)

⚠️ **Considerations:**
- Uses 4-8GB RAM (adequate RAM available on VM 100)
- Transcode files lost on container restart (acceptable, they're temporary)

### Phase 2: GPU Passthrough (High-Impact, Some Risk)
✅ **Positive:**
- **Massive performance improvement** (10-20x faster transcoding)
- **90%+ reduction in CPU usage** during transcodes
- **Much lower power consumption** (NVENC efficiency)
- Better multi-stream support (multiple concurrent transcodes)
- Future-proof (8th gen NVENC, AV1 support)
- Reduced load on Proxmox host (less CPU contention with other VMs)
- Better user experience (instant playback, no buffering)
- Hardware is ideal for this (perfect IOMMU isolation)

❌ **Negative:**
- **GPU dedicated to VM 100** (not available for other VMs or host)
  - Acceptable: Host uses AMD iGPU for console, GPU not needed elsewhere
- Configuration complexity (GPU passthrough, drivers, Docker runtime)
- Potential for driver/compatibility issues (NVIDIA drivers in Linux)
- VM 100 requires GPU for console (may need dummy plug or configure headless)
- Updates may break GPU passthrough (kernel/Proxmox updates)
- Cannot hot-swap GPU (requires VM shutdown)

⚠️ **Considerations:**
- Requires time investment to configure properly
- Previous attempts failed (but likely configuration issues)
- Need to research current best practices for Proxmox 8.x + NVIDIA
- Testing required during low-usage window
- Rollback available but takes time (snapshot restore)

### Long-Term Maintenance
- **tmpfs:** No maintenance, very stable
- **GPU passthrough:**
  - Monitor Proxmox/kernel updates for breakage
  - NVIDIA driver updates may require testing
  - Backup GPU passthrough configuration
  - Document exact configuration for future recovery

## Alternatives Considered

### 1. Intel QuickSync (iGPU Hardware Transcoding)
**Status:** ❌ Not Available
**Reason:** AMD CPU (QuickSync is Intel-only)

Would have been ideal (low complexity, excellent quality) but not an option with current hardware.

### 2. AMD iGPU Passthrough (Raphael Integrated Graphics)
**Status:** ⚠️ Possible but Not Recommended

**Pros:**
- Hardware acceleration (AMD VCE)
- GPU stays available for host console
- Supports H.264 and HEVC

**Cons:**
- Complex IOMMU setup (multiple devices in groups 29-34)
- Less powerful than RTX 4060 Ti
- More difficult to configure than discrete GPU
- May interfere with host graphics
- AMD video drivers can be problematic in Linux

**Decision:** Not worth the complexity when RTX 4060 Ti is available and much better.

### 3. CPU-Only with No Optimizations
**Status:** ❌ Rejected (Current State, Needs Improvement)

Continue using software transcoding with no improvements.

**Cons:**
- High CPU usage affects other VMs
- Slower transcode speeds
- High power consumption
- Poor user experience during high load
- Wasted potential (excellent GPU sitting unused)

**Decision:** Not acceptable given available hardware and easy wins.

### 4. Buy/Use Intel CPU with QuickSync
**Status:** ❌ Not Practical

Would require replacing CPU, motherboard, potentially RAM (DDR4 vs DDR5).

**Cons:**
- Expensive ($500-1000+)
- Downgrade in core count (Ryzen 7 7700 is powerful)
- Significant effort to replace and reconfigure
- QuickSync benefit marginal vs RTX 4060 Ti NVENC

**Decision:** Not worth the cost/effort when better GPU is already available.

### 5. Remote Transcoding Server
**Status:** ❌ Over-Engineered

Set up separate dedicated transcoding server, stream to Emby.

**Cons:**
- Additional hardware required
- Network bandwidth concerns
- Complex configuration
- Maintenance overhead
- Unnecessary when local GPU is available

**Decision:** Over-engineered for single-household use case.

## Implementation Plan

**Phase 1: tmpfs Implementation**
1. Baseline measurements (current transcode performance)
2. Add tmpfs mount to docker-compose (4-8GB)
3. Restart Emby container
4. Test typical transcode scenarios
5. Measure improvement vs baseline
6. Document findings

**Phase 2: GPU Passthrough Implementation**
1. Research current best practices (Proxmox 8.x + NVIDIA RTX 4000 series)
2. Backup VM 100 (snapshot already exists)
3. Configure Proxmox host:
   - Load vfio-pci drivers
   - Add GPU to vfio blacklist
   - Update GRUB/kernel parameters if needed
4. Configure VM 100 for GPU passthrough (add PCI devices)
5. Install NVIDIA drivers in VM 100
6. Configure Docker for nvidia-docker runtime
7. Update Emby docker-compose for GPU access
8. Configure Emby to use NVENC
9. Test and validate
10. Monitor for stability
11. Document configuration

**Phase 3: Testing and Validation**
- Baseline measurements (CPU-only, before tmpfs)
- tmpfs measurements
- GPU passthrough measurements
- Compare: transcode speed, CPU usage, power consumption, quality
- Stress test: multiple concurrent transcodes
- Validate: various codecs (H.264, HEVC, 4K, HDR)

**Phase 4: Documentation**
- Update ADR with actual results
- Create runbook for GPU passthrough maintenance
- Document rollback procedures
- Update Emby stack documentation

## Success Criteria

**Phase 1 (tmpfs):**
- ✅ 10-30% faster transcode start times
- ✅ Reduced disk I/O during transcoding
- ✅ No degradation in quality or stability
- ✅ Memory usage within acceptable limits

**Phase 2 (GPU Passthrough):**
- ✅ GPU visible in VM 100 (`nvidia-smi` works)
- ✅ Docker can access GPU (nvidia-docker runtime)
- ✅ Emby using NVENC for transcoding
- ✅ 10-20x faster transcoding vs CPU-only
- ✅ 90%+ reduction in CPU usage during transcodes
- ✅ No quality degradation vs CPU transcoding
- ✅ Stable over 7 days of normal use
- ✅ Multiple concurrent transcodes work correctly

**Overall:**
- ✅ Better user experience (faster playback start, no buffering)
- ✅ Lower CPU load on Proxmox host
- ✅ Lower power consumption
- ✅ Comprehensive documentation for future maintenance

## Research Artifacts

- **Hardware Audit:** [[docs/research/proxmox-hardware-capabilities|Proxmox Hardware Capabilities]]
- **Task:** [[tasks/current/IN-007-research-emby-transcoding-optimization|IN-007]]
- **Related Configuration:** `stacks/emby/docker-compose.yml`

## Future Considerations

**After Implementation:**
- Consider AV1 encoding for better compression (when client support improves)
- Monitor NVENC quality vs CPU (may need quality tuning)
- Evaluate tone mapping quality (HDR to SDR)
- Consider GPU scheduling for other transcoding tasks (Plex, Jellyfin, etc.)

**Hardware Upgrades:**
- RTX 4060 Ti is excellent for current needs
- Future GPUs will have even better NVENC quality
- No immediate upgrade needed

## References

- **NVIDIA NVENC Support Matrix:** [NVIDIA Video Codec SDK](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new)
- **Proxmox GPU Passthrough Guide:** [Proxmox Wiki - PCI Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)
- **Emby Hardware Acceleration:** [Emby Docs - Hardware Acceleration](https://support.emby.media/support/solutions/articles/44001159092-hardware-acceleration)
- **Docker GPU Support:** [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html)

---

**Decision Status:** Proposed (pending Phase 1 testing)
**Review Date:** After Phase 1 and Phase 2 completion
**Expected ADR Status Update:** Accepted (after successful implementation and validation)
