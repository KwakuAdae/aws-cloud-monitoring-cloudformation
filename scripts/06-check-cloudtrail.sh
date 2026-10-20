#!/usr/bin/env bash
# Phase 9: security auditing. Is the trail logging, what happened in the account, and are logs in S3?
source "$(dirname "$0")/config.sh"
TRAIL="$(out TrailName)"
BUCKET="$(out AuditBucketName)"

step "Trail ${TRAIL}"
aws cloudtrail get-trail-status --name "$TRAIL" \
  --query '{IsLogging:IsLogging, LastDelivery:LatestDeliveryTime, LastError:LatestDeliveryError}' --output table

step "Who did what? Recent management events (CloudTrail Event history)"
for event in RunInstances CreateSecurityGroup CreateStack CreateTopic PutMetricAlarm CreateTrail; do
  aws cloudtrail lookup-events --max-results 1 \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=${event}" \
    --query 'Events[].{Time:EventTime, Event:EventName, User:Username, Source:EventSource}' --output table \
    || echo "   (could not look up ${event}: see CloudTrail → Event history)"
done

step "Log files delivered to s3://${BUCKET}/AWSLogs/ (CloudTrail delivers roughly every 5 minutes)"
COUNT="$(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix AWSLogs/ --query 'length(Contents || `[]`)' --output text)"
echo "   ${COUNT} log file(s)"
aws s3api list-objects-v2 --bucket "$BUCKET" --prefix AWSLogs/ --max-items 5 \
  --query 'Contents[].{Key:Key, Size:Size, Modified:LastModified}' --output table 2>/dev/null || true

step "Bucket protection"
aws s3api get-public-access-block --bucket "$BUCKET" --query PublicAccessBlockConfiguration --output table
aws s3api get-bucket-encryption --bucket "$BUCKET" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault' --output table

echo ""
echo "Note: this trail is single-Region and records management events (not S3 object-level data events)."
echo "✅ Next: ./scripts/07-collect-evidence.sh"
