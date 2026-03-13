#!/bin/bash
# Simulate zone failure

if [ -z "$1" ]; then
    echo "Usage: $0 <ZONE>"
    echo "Example: $0 us-central1-a"
    exit 1
fi

ZONE=$1
INSTANCE_GROUP="uptime-mig"
REGION="us-central1"

echo "Simulating zone failure: $ZONE"
echo ""

# Get all instances in the zone
instances=$(gcloud compute instance-groups managed list-instances "$INSTANCE_GROUP" \
    --region="$REGION" \
    --format="value(instance)" \
    --filter="zone:$ZONE")

if [ -z "$instances" ]; then
    echo "No instances found in zone $ZONE"
    exit 1
fi

echo "Found instances in $ZONE:"
echo "$instances"
echo ""

# Kill the web service on each instance
for instance_url in $instances; do
    instance_name=$(basename "$instance_url")
    echo "Stopping web service on $instance_name..."
    
    gcloud compute ssh "$instance_name" \
        --zone="$ZONE" \
        --command="sudo systemctl stop uptime-app" \
        --ssh-flag="-o StrictHostKeyChecking=no" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "   ✓ Stopped"
    else
        echo "   Failed (might need SSH keys setup)"
    fi
done

echo ""
echo "Done! Zone failure simulated."
echo ""
echo "What should happen:"
echo "   1. Health checks fail"
echo "   2. Load balancer stops sending traffic there"
echo "   3. Other zones keep serving"
echo "   4. Auto-healing recreates instances after ~60s"
echo ""
echo "Watch it:"
echo "   ./monitor-instances.sh <LOAD_BALANCER_IP>"
