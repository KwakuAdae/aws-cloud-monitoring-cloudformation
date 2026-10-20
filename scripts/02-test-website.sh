#!/usr/bin/env bash
# Phase 5: open the business website (NGINX installs in 1-2 minutes after the instance starts).
source "$(dirname "$0")/config.sh"
URL="$(out WebsiteURL)"
ID="$(out InstanceId)"

step "Instance ${ID}"
aws ec2 describe-instances --instance-ids "$ID" \
  --query 'Reservations[0].Instances[0].{State:State.Name, Type:InstanceType, AZ:Placement.AvailabilityZone, PublicIP:PublicIpAddress}' \
  --output table

step "Waiting for ${URL} to answer"
for _ in $(seq 30); do
  if curl -fs --max-time 5 "$URL" >/dev/null; then
    curl -s "$URL" | grep -oE '<h1>[^<]+</h1>|<p>Business[^<]+</p>' | sed 's/<[^>]*>//g;s/^/   /'
    echo ""
    echo "✅ Open in your browser: ${URL}   (HTTP only: a demonstration website)"
    exit 0
  fi
  printf '.'; sleep 10
done
echo ""
echo "⚠️  Not answering yet. Check the instance is running with a public IP, and allow a few minutes for NGINX."
exit 1
