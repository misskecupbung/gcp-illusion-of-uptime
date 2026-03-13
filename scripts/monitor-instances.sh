#!/bin/bash
# Monitor which instances serve requests

if [ -z "$1" ]; then
    echo "Usage: $0 <LOAD_BALANCER_IP>"
    echo "Example: $0 34.120.45.67"
    exit 1
fi

LOAD_BALANCER_IP=$1
URL="http://$LOAD_BALANCER_IP"

echo "Monitoring requests..."
echo "Load Balancer: $URL"
echo "Press Ctrl+C to stop"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track instance counts
declare -A instance_counts

count=0
while true; do
    # Make request and extract instance name
    response=$(curl -s "$URL" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Request failed - LB might not be ready yet...${NC}"
        sleep 2
        continue
    fi
    
    # Extract instance name from HTML response
    instance=$(echo "$response" | grep -oP '(?<=<strong>Instance:</strong> )[^<]+' | head -1)
    zone=$(echo "$response" | grep -oP '(?<=<strong>Zone:</strong> )[^<]+' | head -1)
    
    if [ -z "$instance" ]; then
        echo -e "${YELLOW}Couldn't parse response - backend might be unhealthy${NC}"
        sleep 2
        continue
    fi
    
    # Increment counter for this instance
    instance_counts[$instance]=$((${instance_counts[$instance]:-0} + 1))
    
    count=$((count + 1))
    timestamp=$(date '+%H:%M:%S')
    
    echo -e "${GREEN}✓${NC} [$timestamp] Request #$count -> ${BLUE}$instance${NC} ($zone)"
    
    # Show distribution every 10 requests
    if [ $((count % 10)) -eq 0 ]; then
        echo ""
        echo "Distribution after $count requests:"
        for inst in "${!instance_counts[@]}"; do
            count_for_inst=${instance_counts[$inst]}
            percentage=$((count_for_inst * 100 / count))
            echo "   $inst: $count_for_inst ($percentage%)"
        done
        echo ""
    fi
    
    sleep 1
done
