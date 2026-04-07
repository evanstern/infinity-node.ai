#!/bin/bash
#
# Setup fail2ban for Emby Server
# This script configures fail2ban to protect Emby from brute force attacks
#
# Usage: ./setup-emby-fail2ban.sh [emby-log-path]
#
# If emby-log-path is not provided, will attempt to detect from common locations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default Emby log path (adjust if needed)
EMBY_LOG_PATH="${1:-}"
EMBY_CONFIG_DIR="/mnt/nas/configs/emby"  # Adjust to your Emby config path

echo -e "${GREEN}Setting up fail2ban for Emby Server${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Detect Emby log path if not provided
if [ -z "$EMBY_LOG_PATH" ]; then
    echo -e "${YELLOW}Detecting Emby log path...${NC}"

    # Try common locations
    if [ -d "$EMBY_CONFIG_DIR/logs" ]; then
        EMBY_LOG_PATH="$EMBY_CONFIG_DIR/logs/server-*.txt"
        echo -e "${GREEN}Found logs at: $EMBY_LOG_PATH${NC}"
    elif [ -d "/config/logs" ]; then
        EMBY_LOG_PATH="/config/logs/server-*.txt"
        echo -e "${GREEN}Found logs at: $EMBY_LOG_PATH${NC}"
    else
        echo -e "${RED}Could not detect Emby log path. Please provide it as argument:${NC}"
        echo "  $0 /path/to/emby/logs/server-*.txt"
        exit 1
    fi
fi

# Verify log path exists
if ! ls $EMBY_LOG_PATH >/dev/null 2>&1; then
    echo -e "${RED}Error: Log path does not exist: $EMBY_LOG_PATH${NC}"
    echo "Please check your Emby log location and try again."
    exit 1
fi

# Install fail2ban if not installed
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${YELLOW}Installing fail2ban...${NC}"
    apt-get update
    apt-get install -y fail2ban
else
    echo -e "${GREEN}fail2ban is already installed${NC}"
fi

# Create Emby filter
echo -e "${YELLOW}Creating Emby filter...${NC}"
cat > /etc/fail2ban/filter.d/emby.conf << 'EOF'
[Definition]
# Match failed authentication attempts
failregex = ^.*Authentication request for <HOST>.*has been denied.*$
            ^.*Authentication request for .* from <HOST>.*has been denied.*$
            ^.*Invalid username or password entered.*<HOST>.*$
            ^.*Failed login attempt.*<HOST>.*$

# Ignore successful logins
ignoreregex =
EOF

# Create Emby jail configuration
echo -e "${YELLOW}Creating Emby jail configuration...${NC}"
cat > /etc/fail2ban/jail.d/emby.conf << EOF
[emby]
enabled = true
port = 8096,8920
filter = emby
logpath = $EMBY_LOG_PATH
maxretry = 5
findtime = 600
bantime = 3600
action = iptables[name=Emby, port=8096, protocol=tcp]
         iptables[name=Emby-HTTPS, port=8920, protocol=tcp]
         iptables[name=Emby-External, port=443, protocol=tcp]
EOF

# Test the filter
echo -e "${YELLOW}Testing fail2ban filter...${NC}"
if fail2ban-regex "$EMBY_LOG_PATH" /etc/fail2ban/filter.d/emby.conf | grep -q "Matched"; then
    echo -e "${GREEN}Filter test passed${NC}"
else
    echo -e "${YELLOW}Warning: Filter test found no matches. This is OK if there are no failed logins in the logs.${NC}"
fi

# Restart fail2ban
echo -e "${YELLOW}Restarting fail2ban...${NC}"
systemctl restart fail2ban
systemctl enable fail2ban

# Wait a moment for service to start
sleep 2

# Check status
echo -e "${GREEN}Checking fail2ban status...${NC}"
if fail2ban-client status emby >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Emby jail is active${NC}"
    fail2ban-client status emby
else
    echo -e "${RED}Error: Emby jail is not active. Check fail2ban logs:${NC}"
    echo "  tail -f /var/log/fail2ban.log"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ fail2ban setup complete!${NC}"
echo ""
echo "Configuration:"
echo "  - Max retries: 5"
echo "  - Find time: 600 seconds (10 minutes)"
echo "  - Ban time: 3600 seconds (1 hour)"
echo "  - Log path: $EMBY_LOG_PATH"
echo ""
echo "Useful commands:"
echo "  sudo fail2ban-client status emby          # Check status"
echo "  sudo fail2ban-client status emby -v       # Detailed status"
echo "  sudo fail2ban-client set emby banip IP    # Manually ban IP"
echo "  sudo fail2ban-client set emby unbanip IP  # Manually unban IP"
echo "  sudo tail -f /var/log/fail2ban.log        # Watch fail2ban logs"
