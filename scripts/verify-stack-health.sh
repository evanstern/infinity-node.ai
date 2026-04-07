#!/bin/bash
#
# verify-stack-health.sh
#
# Purpose: Verify all containers in a Docker Compose stack are healthy
#
# This script checks that all containers in a compose project have started
# successfully and are reporting healthy status (if health checks are configured).
#
# Usage:
#   ./verify-stack-health.sh <compose-dir> [timeout]
#   ./verify-stack-health.sh <stack-name> [timeout]  (uses docker compose ls to find project)
#
# Arguments:
#   compose-dir: Path to directory containing docker-compose.yml
#                OR name of a running compose project
#   timeout: (Optional) Maximum wait time in seconds (default: 120)
#
# Examples:
#   # Verify stack from compose directory
#   ./verify-stack-health.sh /opt/stacks/homepage
#
#   # Verify a running compose project by name
#   ./verify-stack-health.sh homepage
#
#   # Verify with custom 5 minute timeout
#   ./verify-stack-health.sh /opt/stacks/paperless-ngx 300
#
# Exit Codes:
#   0 - All containers healthy
#   1 - Invalid arguments or prerequisites
#   3 - Containers failed to start or unhealthy
#   4 - Timeout reached

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${BLUE}→ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Validate arguments
if [ $# -lt 1 ]; then
    error "Missing required arguments"
    echo "Usage: $0 <compose-dir|stack-name> [timeout]" >&2
    exit 1
fi

STACK_REF="$1"
TIMEOUT="${2:-120}"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    error "docker not found"
    exit 1
fi

# Determine compose command args
COMPOSE_ARGS=()
if [ -d "$STACK_REF" ]; then
    # Directory path provided — use -f to point at the compose file
    COMPOSE_FILE="$STACK_REF/docker-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "No docker-compose.yml found in $STACK_REF"
        exit 1
    fi
    COMPOSE_ARGS=(-f "$COMPOSE_FILE")
    STACK_NAME="$(basename "$STACK_REF")"
else
    # Treat as project name
    COMPOSE_ARGS=(-p "$STACK_REF")
    STACK_NAME="$STACK_REF"
fi

info "Verifying stack: $STACK_NAME"
info "Timeout: ${TIMEOUT}s"

START_TIME=$(date +%s)
CHECK_INTERVAL=5
ALL_HEALTHY=false

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $TIMEOUT ]; then
        error "Timeout reached after ${TIMEOUT}s"
        exit 4
    fi

    # Get container status via docker compose ps
    PS_OUTPUT=$(docker compose "${COMPOSE_ARGS[@]}" ps --format json 2>/dev/null) || true

    if [ -z "$PS_OUTPUT" ]; then
        warn "No containers found for stack $STACK_NAME"
        sleep $CHECK_INTERVAL
        continue
    fi

    # docker compose ps --format json outputs one JSON object per line
    CONTAINER_COUNT=0
    RUNNING_COUNT=0
    HEALTHY_COUNT=0
    UNHEALTHY_COUNT=0
    STARTING_COUNT=0
    FAILED_CONTAINERS=""

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ((CONTAINER_COUNT++))

        NAME=$(echo "$line" | jq -r '.Name // .Service // "unknown"')
        STATE=$(echo "$line" | jq -r '.State // "unknown"')
        HEALTH=$(echo "$line" | jq -r '.Health // "none"')
        STATUS=$(echo "$line" | jq -r '.Status // "unknown"')

        if [ "$STATE" != "running" ]; then
            FAILED_CONTAINERS="$FAILED_CONTAINERS\n  $NAME: $STATE ($STATUS)"
            continue
        fi

        ((RUNNING_COUNT++))

        # Check health status if available
        case "$HEALTH" in
            healthy)
                ((HEALTHY_COUNT++))
                info "  $NAME: healthy"
                ;;
            unhealthy)
                ((UNHEALTHY_COUNT++))
                warn "  $NAME: unhealthy"
                FAILED_CONTAINERS="$FAILED_CONTAINERS\n  $NAME: unhealthy"
                ;;
            starting)
                ((STARTING_COUNT++))
                info "  $NAME: starting..."
                ;;
            *)
                # No health check configured, running is good enough
                ((HEALTHY_COUNT++))
                info "  $NAME: running (no health check)"
                ;;
        esac
    done <<< "$PS_OUTPUT"

    if [ "$CONTAINER_COUNT" -eq 0 ]; then
        warn "No containers found for stack $STACK_NAME"
        sleep $CHECK_INTERVAL
        continue
    fi

    info "Found $CONTAINER_COUNT containers (${ELAPSED}s elapsed)"

    # Check if all containers are healthy
    if [ $RUNNING_COUNT -eq $CONTAINER_COUNT ] && [ $UNHEALTHY_COUNT -eq 0 ] && [ $STARTING_COUNT -eq 0 ]; then
        ALL_HEALTHY=true
        break
    fi

    if [ $UNHEALTHY_COUNT -gt 0 ]; then
        error "Some containers are unhealthy:"
        echo -e "$FAILED_CONTAINERS"
        exit 3
    fi

    if [ -n "$FAILED_CONTAINERS" ]; then
        error "Some containers failed to start:"
        echo -e "$FAILED_CONTAINERS"
        exit 3
    fi

    info "Waiting for containers to be ready... ($STARTING_COUNT still starting)"
    sleep $CHECK_INTERVAL
done

echo ""
success "All $CONTAINER_COUNT containers are healthy!"
success "Stack $STACK_NAME is ready"

exit 0
