#!/usr/bin/env bash
#
# check-proxmox-resources.sh
#
# Displays comprehensive resource information for Proxmox host including:
# - Total CPU and memory capacity
# - Per-VM resource allocations
# - Current usage and availability
# - Resource allocation percentages
#
# Requirements:
#   - SSH access to Proxmox host
#
# Usage:
#   ./check-proxmox-resources.sh [--json]
#
# Options:
#   --json    Output in JSON format for programmatic use
#

set -euo pipefail

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.81}"
PROXMOX_USER="${PROXMOX_USER:-root}"
OUTPUT_JSON=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            grep "^#" "$0" | grep -v "#!/" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to run SSH command
ssh_cmd() {
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
}

# Gather host information
echo "Gathering Proxmox resource information..." >&2

# Get CPU info
CPU_INFO=$(ssh_cmd "lscpu | grep -E '^CPU\(s\)|^Model name|^Thread|^Core|^Socket'")
TOTAL_LOGICAL_CORES=$(echo "$CPU_INFO" | grep "^CPU(s):" | awk '{print $2}')
CPU_MODEL=$(echo "$CPU_INFO" | grep "^Model name:" | sed 's/Model name:[[:space:]]*//')
THREADS_PER_CORE=$(echo "$CPU_INFO" | grep "^Thread(s) per core:" | awk '{print $4}')
CORES_PER_SOCKET=$(echo "$CPU_INFO" | grep "^Core(s) per socket:" | awk '{print $4}')
SOCKETS=$(echo "$CPU_INFO" | grep "^Socket(s):" | awk '{print $2}')
PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))

# Get memory info
MEMORY_INFO=$(ssh_cmd "free -b | grep ^Mem:")
TOTAL_MEMORY_BYTES=$(echo "$MEMORY_INFO" | awk '{print $2}')
USED_MEMORY_BYTES=$(echo "$MEMORY_INFO" | awk '{print $3}')
FREE_MEMORY_BYTES=$(echo "$MEMORY_INFO" | awk '{print $4}')
AVAILABLE_MEMORY_BYTES=$(echo "$MEMORY_INFO" | awk '{print $7}')

# Convert to GB for display
TOTAL_MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEMORY_BYTES/1024/1024/1024}")
USED_MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MEMORY_BYTES/1024/1024/1024}")
AVAILABLE_MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $AVAILABLE_MEMORY_BYTES/1024/1024/1024}")

# Get VM list and details
VM_DATA=$(ssh_cmd "
qm list | tail -n +2 | while read VMID NAME STATUS REST; do
    [[ -z \"\$VMID\" ]] && continue
    CORES=\$(qm config \$VMID | grep '^cores:' | awk '{print \$2}')
    MEMORY=\$(qm config \$VMID | grep '^memory:' | awk '{print \$2}')
    echo \"\$VMID|\$NAME|\$STATUS|\$CORES|\$MEMORY\"
done
")

# Calculate totals
TOTAL_ALLOCATED_CORES=0
TOTAL_ALLOCATED_MEMORY=0
RUNNING_ALLOCATED_CORES=0
RUNNING_ALLOCATED_MEMORY=0
VM_COUNT=0

# Store VM data for later display
VM_INFO_ARRAY=()

while IFS='|' read -r VMID NAME STATUS CORES MEMORY; do
    [[ -z "$VMID" ]] && continue

    VM_COUNT=$((VM_COUNT + 1))
    VM_INFO_ARRAY+=("$VMID|$NAME|$STATUS|$CORES|$MEMORY")

    TOTAL_ALLOCATED_CORES=$((TOTAL_ALLOCATED_CORES + CORES))
    TOTAL_ALLOCATED_MEMORY=$((TOTAL_ALLOCATED_MEMORY + MEMORY))

    if [[ "$STATUS" == "running" ]]; then
        RUNNING_ALLOCATED_CORES=$((RUNNING_ALLOCATED_CORES + CORES))
        RUNNING_ALLOCATED_MEMORY=$((RUNNING_ALLOCATED_MEMORY + MEMORY))
    fi
done <<< "$VM_DATA"

# Calculate percentages
CORE_OVERSUBSCRIPTION=$(awk "BEGIN {printf \"%.1f\", ($RUNNING_ALLOCATED_CORES/$TOTAL_LOGICAL_CORES)*100}")
MEMORY_USAGE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($RUNNING_ALLOCATED_MEMORY*1024*1024/$TOTAL_MEMORY_BYTES)*100}")

# Output
if [[ "$OUTPUT_JSON" == true ]]; then
    # JSON output
    cat << EOF
{
  "host": {
    "hostname": "$PROXMOX_HOST",
    "cpu": {
      "model": "$CPU_MODEL",
      "physical_cores": $PHYSICAL_CORES,
      "logical_cores": $TOTAL_LOGICAL_CORES,
      "sockets": $SOCKETS,
      "threads_per_core": $THREADS_PER_CORE
    },
    "memory": {
      "total_bytes": $TOTAL_MEMORY_BYTES,
      "total_gb": $TOTAL_MEMORY_GB,
      "used_bytes": $USED_MEMORY_BYTES,
      "used_gb": $USED_MEMORY_GB,
      "available_bytes": $AVAILABLE_MEMORY_BYTES,
      "available_gb": $AVAILABLE_MEMORY_GB
    }
  },
  "vms": [
EOF

    FIRST=true
    for vm_info in "${VM_INFO_ARRAY[@]}"; do
        IFS='|' read -r VMID NAME STATUS CORES MEMORY <<< "$vm_info"

        [[ "$FIRST" == false ]] && echo "    ,"
        FIRST=false

        cat << EOF
    {
      "vmid": $VMID,
      "name": "$NAME",
      "status": "$STATUS",
      "cores": $CORES,
      "memory_mb": $MEMORY
    }
EOF
    done

    cat << EOF

  ],
  "allocation": {
    "total": {
      "cores": $TOTAL_ALLOCATED_CORES,
      "memory_mb": $TOTAL_ALLOCATED_MEMORY
    },
    "running": {
      "cores": $RUNNING_ALLOCATED_CORES,
      "memory_mb": $RUNNING_ALLOCATED_MEMORY,
      "core_oversubscription_percent": $CORE_OVERSUBSCRIPTION,
      "memory_usage_percent": $MEMORY_USAGE_PERCENT
    }
  }
}
EOF
else
    # Human-readable output
    echo
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}        PROXMOX RESOURCE REPORT - $PROXMOX_HOST${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    # Hardware section
    echo -e "${BOLD}${BLUE}HARDWARE RESOURCES${NC}"
    echo -e "${BOLD}CPU:${NC}"
    echo -e "  Model:          $CPU_MODEL"
    echo -e "  Physical cores: ${GREEN}$PHYSICAL_CORES${NC} (across $SOCKETS socket(s))"
    echo -e "  Logical cores:  ${GREEN}$TOTAL_LOGICAL_CORES${NC} ($THREADS_PER_CORE threads per core)"
    echo
    echo -e "${BOLD}Memory:${NC}"
    echo -e "  Total:          ${GREEN}${TOTAL_MEMORY_GB} GB${NC}"
    echo -e "  Used:           ${YELLOW}${USED_MEMORY_GB} GB${NC}"
    echo -e "  Available:      ${GREEN}${AVAILABLE_MEMORY_GB} GB${NC}"
    echo

    # VM allocations section
    echo -e "${BOLD}${BLUE}VIRTUAL MACHINE ALLOCATIONS${NC}"
    echo
    printf "%-8s %-25s %-10s %8s %12s\n" "VMID" "NAME" "STATUS" "CORES" "MEMORY"
    echo "────────────────────────────────────────────────────────────────"

    for vm_info in "${VM_INFO_ARRAY[@]}"; do
        IFS='|' read -r VMID NAME STATUS CORES MEMORY <<< "$vm_info"

        STATUS_COLOR=$NC
        if [[ "$STATUS" == "running" ]]; then
            STATUS_COLOR=$GREEN
        else
            STATUS_COLOR=$YELLOW
        fi

        MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $MEMORY/1024}")

        printf "%-8s %-25s ${STATUS_COLOR}%-10s${NC} %8s %9s GB\n" \
            "$VMID" \
            "$NAME" \
            "$STATUS" \
            "$CORES" \
            "$MEMORY_GB"
    done

    echo

    # Summary section
    echo -e "${BOLD}${BLUE}ALLOCATION SUMMARY${NC}"
    echo
    echo -e "${BOLD}All VMs (including stopped):${NC}"
    TOTAL_ALLOCATED_MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_ALLOCATED_MEMORY/1024}")
    echo -e "  Cores:  $TOTAL_ALLOCATED_CORES allocated"
    echo -e "  Memory: ${TOTAL_ALLOCATED_MEMORY_GB} GB allocated"
    echo

    echo -e "${BOLD}Running VMs only:${NC}"
    RUNNING_ALLOCATED_MEMORY_GB=$(awk "BEGIN {printf \"%.1f\", $RUNNING_ALLOCATED_MEMORY/1024}")
    echo -e "  Cores:  ${RUNNING_ALLOCATED_CORES} allocated (${CORE_OVERSUBSCRIPTION}% of ${TOTAL_LOGICAL_CORES} logical cores)"
    echo -e "  Memory: ${RUNNING_ALLOCATED_MEMORY_GB} GB allocated (${MEMORY_USAGE_PERCENT}% of ${TOTAL_MEMORY_GB} GB)"
    echo

    # Status indicators
    echo -e "${BOLD}${BLUE}RESOURCE STATUS${NC}"

    # Core oversubscription status
    if (( $(echo "$CORE_OVERSUBSCRIPTION > 150" | bc -l) )); then
        echo -e "  CPU:    ${RED}⚠ High oversubscription${NC} (${CORE_OVERSUBSCRIPTION}%)"
    elif (( $(echo "$CORE_OVERSUBSCRIPTION > 100" | bc -l) )); then
        echo -e "  CPU:    ${YELLOW}✓ Oversubscribed${NC} (${CORE_OVERSUBSCRIPTION}%) - normal for VMs"
    else
        echo -e "  CPU:    ${GREEN}✓ Healthy${NC} (${CORE_OVERSUBSCRIPTION}% allocated)"
    fi

    # Memory usage status
    if (( $(echo "$MEMORY_USAGE_PERCENT > 90" | bc -l) )); then
        echo -e "  Memory: ${RED}⚠ High usage${NC} (${MEMORY_USAGE_PERCENT}%)"
    elif (( $(echo "$MEMORY_USAGE_PERCENT > 75" | bc -l) )); then
        echo -e "  Memory: ${YELLOW}✓ Moderate usage${NC} (${MEMORY_USAGE_PERCENT}%)"
    else
        echo -e "  Memory: ${GREEN}✓ Healthy${NC} (${MEMORY_USAGE_PERCENT}% allocated)"
    fi

    echo
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
fi
