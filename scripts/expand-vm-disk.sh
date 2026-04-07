#!/usr/bin/env bash
# expand-vm-disk.sh - Automate Proxmox VM disk expansion
#
# Usage:
#   ./expand-vm-disk.sh <vm-id> <additional-size-GB> [proxmox-host] [ssh-user]
#
# Examples:
#   ./expand-vm-disk.sh 103 50
#   ./expand-vm-disk.sh 103 50 192.168.1.81 root
#
# Description:
#   Automates the process of expanding a Proxmox VM's disk by:
#   1. Expanding the disk in Proxmox (via qm resize)
#   2. Rescanning SCSI on the VM
#   3. Extending the physical volume (PV)
#   4. Extending the logical volume (LV)
#   5. Resizing the filesystem
#   6. Verifying the expansion

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PROXMOX_HOST="${3:-192.168.1.81}"
PROXMOX_USER="${4:-root}"
VM_SSH_USER="evan"

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <vm-id> <additional-size-GB> [proxmox-host] [ssh-user]"
    echo ""
    echo "Examples:"
    echo "  $0 103 50                      # Add 50GB to VM 103"
    echo "  $0 103 50 192.168.1.81 root  # With explicit Proxmox host"
    echo ""
    echo "This script will:"
    echo "  1. Show current VM disk status"
    echo "  2. Request confirmation before proceeding"
    echo "  3. Expand disk in Proxmox"
    echo "  4. Extend LVM volumes on the VM"
    echo "  5. Resize the filesystem"
    echo "  6. Verify the expansion"
    exit 1
fi

VM_ID="$1"
ADDITIONAL_SIZE="$2"

# Validate VM ID is numeric
if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: VM ID must be numeric${NC}"
    exit 1
fi

# Validate size is numeric
if ! [[ "$ADDITIONAL_SIZE" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Size must be numeric (GB)${NC}"
    exit 1
fi

# Print section header
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Get VM IP address from Proxmox
get_vm_ip() {
    local vm_id="$1"
    local ip
    ip=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm guest cmd $vm_id network-get-interfaces" 2>/dev/null | \
         python3 -c '
import json, sys
from ipaddress import ip_address

raw_input = sys.stdin.read()
start = raw_input.find("[")
end = raw_input.rfind("]")
if start == -1 or end == -1 or end < start:
    sys.exit(1)

try:
    interfaces = json.loads(raw_input[start:end+1])
except json.JSONDecodeError:
    sys.exit(1)

for iface in interfaces:
    for record in iface.get("ip-addresses", []):
        raw = record.get("ip-address")
        if not raw:
            continue
        try:
            parsed = ip_address(raw)
        except ValueError:
            continue
        if parsed.version != 4:
            continue
        if parsed.is_loopback or parsed.is_link_local:
            continue
        print(raw)
        sys.exit(0)
sys.exit(1)
')
    echo "$ip"
}

print_header "VM Disk Expansion - VM $VM_ID"
echo "Proxmox Host: $PROXMOX_HOST"
echo "Additional Size: ${ADDITIONAL_SIZE}GB"

# Verify Proxmox connectivity
print_header "Step 1: Verifying Connectivity"
if ! ssh -o ConnectTimeout=5 "$PROXMOX_USER@$PROXMOX_HOST" "echo 'Connected'" &>/dev/null; then
    print_error "Cannot connect to Proxmox host $PROXMOX_USER@$PROXMOX_HOST"
    exit 1
fi
print_success "Connected to Proxmox host"

# Check if VM exists
if ! ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $VM_ID" &>/dev/null; then
    print_error "VM $VM_ID does not exist on Proxmox host"
    exit 1
fi
print_success "VM $VM_ID exists"

# Get VM IP
VM_IP=$(get_vm_ip "$VM_ID")
if [ -z "$VM_IP" ]; then
    print_error "Could not determine IP address for VM $VM_ID"
    echo "Please ensure the VM is running and has qemu-guest-agent installed"
    exit 1
fi
print_success "VM IP address: $VM_IP"

# Verify VM connectivity
if ! ssh -o ConnectTimeout=5 "$VM_SSH_USER@$VM_IP" "echo 'Connected'" &>/dev/null; then
    print_error "Cannot connect to VM at $VM_SSH_USER@$VM_IP"
    exit 1
fi
print_success "Connected to VM"

# Show current disk status
print_header "Step 2: Current Disk Status"

echo "On Proxmox:"
ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $VM_ID | grep ^scsi0"

echo ""
echo "On VM:"
ssh "$VM_SSH_USER@$VM_IP" "df -h /" 2>/dev/null

echo ""
ssh "$VM_SSH_USER@$VM_IP" "sudo pvs && sudo lvs" 2>/dev/null

# Confirmation
print_header "Step 3: Confirmation"
print_warning "About to expand VM $VM_ID disk by ${ADDITIONAL_SIZE}GB"
echo ""
echo "This operation will:"
echo "  1. Expand the disk in Proxmox"
echo "  2. Extend the LVM volumes"
echo "  3. Resize the filesystem"
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled"
    exit 0
fi

# Perform expansion on Proxmox
print_header "Step 4: Expanding Disk in Proxmox"
if ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm resize $VM_ID scsi0 +${ADDITIONAL_SIZE}G"; then
    print_success "Disk expanded in Proxmox"
else
    print_error "Failed to expand disk in Proxmox"
    exit 1
fi

# Wait a moment for changes to propagate
sleep 2

# Rescan SCSI on VM
print_header "Step 5: Rescanning SCSI Bus on VM"
if ssh "$VM_SSH_USER@$VM_IP" "echo 1 | sudo tee /sys/class/block/sda/device/rescan > /dev/null"; then
    print_success "SCSI bus rescanned"
else
    print_error "Failed to rescan SCSI bus"
    exit 1
fi

sleep 2

# Extend partition to use new disk space
print_header "Step 6: Expanding Partition"
GROWPART_CMD="sudo growpart /dev/sda 3"
PARTED_CMD="sudo parted /dev/sda --script resizepart 3 100%"
if ssh "$VM_SSH_USER@$VM_IP" "$GROWPART_CMD" &>/dev/null; then
    print_success "Partition /dev/sda3 expanded with growpart"
elif ssh "$VM_SSH_USER@$VM_IP" "$PARTED_CMD" &>/dev/null; then
    print_warning "growpart unavailable; used parted to resize partition"
else
    print_error "Failed to resize partition /dev/sda3. Install cloud-guest-utils or resize manually."
    exit 1
fi

sleep 2

# Extend physical volume
print_header "Step 7: Extending Physical Volume"
if ssh "$VM_SSH_USER@$VM_IP" "sudo pvresize /dev/sda3"; then
    print_success "Physical volume extended"
else
    print_error "Failed to extend physical volume"
    exit 1
fi

# Extend logical volume
print_header "Step 8: Extending Logical Volume"
if ssh "$VM_SSH_USER@$VM_IP" "sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv"; then
    print_success "Logical volume extended"
else
    print_error "Failed to extend logical volume"
    exit 1
fi

# Resize filesystem
print_header "Step 9: Resizing Filesystem"
if ssh "$VM_SSH_USER@$VM_IP" "sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv"; then
    print_success "Filesystem resized"
else
    print_error "Failed to resize filesystem"
    exit 1
fi

# Verify expansion
print_header "Step 10: Verification"

echo "New disk status on VM:"
ssh "$VM_SSH_USER@$VM_IP" "df -h /" 2>/dev/null

echo ""
echo "LVM status:"
ssh "$VM_SSH_USER@$VM_IP" "sudo pvs && sudo lvs" 2>/dev/null

echo ""
print_success "Disk expansion completed successfully!"

# Check for errors in dmesg
echo ""
echo "Checking for errors in dmesg (last 20 lines):"
ssh "$VM_SSH_USER@$VM_IP" "sudo dmesg | tail -20" 2>/dev/null

print_header "EXPANSION COMPLETE"
echo "VM $VM_ID disk has been expanded by ${ADDITIONAL_SIZE}GB"
echo "Please verify that all services are running correctly"
