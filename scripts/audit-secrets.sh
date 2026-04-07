#!/usr/bin/env bash
#
# audit-secrets.sh - Audit docker-compose files for secrets
#
# Description:
#   Scans all docker-compose.yml files in the stacks/ directory for potential
#   secrets (passwords, API keys, tokens, etc.). Identifies:
#   - Secrets using environment variable references (${VAR}) - GOOD
#   - Hardcoded secrets (plain text values) - BAD
#   - Commented-out secrets - NEEDS CLEANUP
#   - Services with .env files vs. those without
#
# Usage:
#   ./audit-secrets.sh [OPTIONS]
#
# Options:
#   -v, --verbose    Show detailed output for each file
#   -o, --output     Output format: text (default), json, markdown
#   -h, --help       Show this help message
#
# Examples:
#   ./audit-secrets.sh                    # Basic audit
#   ./audit-secrets.sh --verbose          # Detailed output
#   ./audit-secrets.sh -o markdown        # Markdown formatted output
#
# Exit Codes:
#   0 - No hardcoded secrets found
#   1 - Hardcoded secrets detected (security issue)
#   2 - Invalid arguments
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
VERBOSE=false
OUTPUT_FORMAT="text"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACKS_DIR="${REPO_ROOT}/stacks"

# Counters
TOTAL_STACKS=0
STACKS_WITH_ENV_REFS=0
STACKS_WITH_HARDCODED=0
STACKS_WITH_COMMENTED=0
STACKS_WITH_ENV_FILE=0

# Arrays to store findings
declare -a HARDCODED_SECRETS
declare -a COMMENTED_SECRETS
declare -a ENV_VAR_REFS

# Help message
show_help() {
    sed -n '/^# Description:/,/^$/p' "$0" | sed 's/^# //; s/^#//'
    sed -n '/^# Usage:/,/^# Exit Codes:/p' "$0" | sed 's/^# //; s/^#//'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
    esac
done

# Validate output format
if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|markdown)$ ]]; then
    echo "Error: Invalid output format: $OUTPUT_FORMAT" >&2
    echo "Valid formats: text, json, markdown" >&2
    exit 2
fi

# Check if stacks directory exists
if [[ ! -d "$STACKS_DIR" ]]; then
    echo "Error: Stacks directory not found: $STACKS_DIR" >&2
    exit 1
fi

# Function to check for .env file
has_env_file() {
    local stack_dir="$1"
    [[ -f "${stack_dir}/.env" ]]
}

# Function to scan a docker-compose file
scan_compose_file() {
    local compose_file="$1"
    local stack_name=$(basename "$(dirname "$compose_file")")

    ((TOTAL_STACKS++))

    if $VERBOSE; then
        echo -e "${BLUE}Scanning: ${stack_name}${NC}"
    fi

    # Check for .env file
    if has_env_file "$(dirname "$compose_file")"; then
        ((STACKS_WITH_ENV_FILE++))
    fi

    # Find lines with secret-related keywords
    local secret_lines=$(grep -n -iE "(password|secret|api_key|token|credentials|private_key)" "$compose_file" || true)

    if [[ -z "$secret_lines" ]]; then
        if $VERBOSE; then
            echo "  No secret keywords found"
        fi
        return
    fi

    # Parse each line
    while IFS= read -r line; do
        local line_num=$(echo "$line" | cut -d: -f1)
        local content=$(echo "$line" | cut -d: -f2-)

        # Skip commented lines for hardcoded check, but track them separately
        if echo "$content" | grep -q '^\s*#'; then
            ((STACKS_WITH_COMMENTED++))
            COMMENTED_SECRETS+=("${stack_name}:${line_num}:${content}")
            continue
        fi

        # Check if it uses environment variable (${VAR} or $VAR)
        if echo "$content" | grep -qE '\$\{[A-Z_]+\}|\$[A-Z_]+'; then
            ((STACKS_WITH_ENV_REFS++))
            ENV_VAR_REFS+=("${stack_name}:${line_num}:${content}")
            if $VERBOSE; then
                echo -e "  ${GREEN}✓${NC} Line $line_num: Uses env var"
            fi
        # Check for hardcoded values (key: value pattern where value is not a variable)
        elif echo "$content" | grep -qE ':\s*[^$#]' && ! echo "$content" | grep -qE ':\s*$'; then
            ((STACKS_WITH_HARDCODED++))
            HARDCODED_SECRETS+=("${stack_name}:${line_num}:${content}")
            if $VERBOSE; then
                echo -e "  ${RED}✗${NC} Line $line_num: HARDCODED SECRET"
            fi
        fi
    done <<< "$secret_lines"
}

# Scan all docker-compose files
echo "Scanning docker-compose files in: $STACKS_DIR"
echo ""

for compose_file in "$STACKS_DIR"/*/docker-compose.yml; do
    if [[ -f "$compose_file" ]]; then
        scan_compose_file "$compose_file"
    fi
done

# Output results based on format
case "$OUTPUT_FORMAT" in
    text)
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "                    SECRET AUDIT SUMMARY"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Total Stacks Scanned: $TOTAL_STACKS"
        echo "Stacks with .env file: $STACKS_WITH_ENV_FILE"
        echo ""
        echo -e "${GREEN}Stacks using env var references:${NC} $STACKS_WITH_ENV_REFS"
        echo -e "${RED}Stacks with hardcoded secrets:${NC} $STACKS_WITH_HARDCODED"
        echo -e "${YELLOW}Stacks with commented secrets:${NC} $STACKS_WITH_COMMENTED"
        echo ""

        if [[ ${#HARDCODED_SECRETS[@]} -gt 0 ]]; then
            echo -e "${RED}⚠️  HARDCODED SECRETS FOUND (SECURITY ISSUE):${NC}"
            for secret in "${HARDCODED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "$secret"
                echo "  • $stack (line $line): ${content:0:60}..."
            done
            echo ""
        fi

        if [[ ${#COMMENTED_SECRETS[@]} -gt 0 ]]; then
            echo -e "${YELLOW}📝 COMMENTED SECRETS (CLEANUP RECOMMENDED):${NC}"
            for secret in "${COMMENTED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "$secret"
                echo "  • $stack (line $line): ${content:0:60}..."
            done
            echo ""
        fi

        if [[ $STACKS_WITH_HARDCODED -eq 0 ]]; then
            echo -e "${GREEN}✓ No hardcoded secrets detected${NC}"
            echo ""
        fi
        ;;

    markdown)
        echo "# Secret Audit Report"
        echo ""
        echo "**Date:** $(date +%Y-%m-%d)"
        echo "**Stacks Scanned:** $TOTAL_STACKS"
        echo ""
        echo "## Summary"
        echo ""
        echo "| Metric | Count |"
        echo "|--------|-------|"
        echo "| Total Stacks | $TOTAL_STACKS |"
        echo "| Stacks with .env file | $STACKS_WITH_ENV_FILE |"
        echo "| Using env var references | $STACKS_WITH_ENV_REFS |"
        echo "| ⚠️ Hardcoded secrets | $STACKS_WITH_HARDCODED |"
        echo "| Commented secrets | $STACKS_WITH_COMMENTED |"
        echo ""

        if [[ ${#HARDCODED_SECRETS[@]} -gt 0 ]]; then
            echo "## ⚠️ Hardcoded Secrets (SECURITY ISSUE)"
            echo ""
            for secret in "${HARDCODED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "$secret"
                echo "- **$stack** (line $line): \`${content:0:60}...\`"
            done
            echo ""
        fi

        if [[ ${#COMMENTED_SECRETS[@]} -gt 0 ]]; then
            echo "## Commented Secrets (Cleanup Recommended)"
            echo ""
            for secret in "${COMMENTED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "$secret"
                echo "- **$stack** (line $line): \`${content:0:60}...\`"
            done
            echo ""
        fi
        ;;

    json)
        echo "{"
        echo "  \"date\": \"$(date -Iseconds)\","
        echo "  \"total_stacks\": $TOTAL_STACKS,"
        echo "  \"stacks_with_env_file\": $STACKS_WITH_ENV_FILE,"
        echo "  \"stacks_with_env_refs\": $STACKS_WITH_ENV_REFS,"
        echo "  \"stacks_with_hardcoded\": $STACKS_WITH_HARDCODED,"
        echo "  \"stacks_with_commented\": $STACKS_WITH_COMMENTED,"
        echo "  \"hardcoded_secrets\": ["
        if [[ ${#HARDCODED_SECRETS[@]} -gt 0 ]]; then
            for i in "${!HARDCODED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "${HARDCODED_SECRETS[$i]}"
                echo "    {\"stack\": \"$stack\", \"line\": $line, \"content\": \"${content:0:60}...\"}"
                [[ $i -lt $((${#HARDCODED_SECRETS[@]} - 1)) ]] && echo ","
            done
        fi
        echo "  ],"
        echo "  \"commented_secrets\": ["
        if [[ ${#COMMENTED_SECRETS[@]} -gt 0 ]]; then
            for i in "${!COMMENTED_SECRETS[@]}"; do
                IFS=':' read -r stack line content <<< "${COMMENTED_SECRETS[$i]}"
                echo "    {\"stack\": \"$stack\", \"line\": $line, \"content\": \"${content:0:60}...\"}"
                [[ $i -lt $((${#COMMENTED_SECRETS[@]} - 1)) ]] && echo ","
            done
        fi
        echo "  ]"
        echo "}"
        ;;
esac

# Exit with error code if hardcoded secrets found
if [[ $STACKS_WITH_HARDCODED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
