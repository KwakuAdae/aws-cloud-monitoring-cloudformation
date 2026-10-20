#!/usr/bin/env bash
# Phase 6: check the email subscription is confirmed, then publish a test notification.
source "$(dirname "$0")/config.sh"
TOPIC="$(out SNSTopicArn)"

step "Subscriptions on ${TOPIC##*:}"
aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" \
  --query 'Subscriptions[].{Protocol:Protocol, Endpoint:Endpoint, Status:SubscriptionArn}' --output table
if aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" --query 'Subscriptions[].SubscriptionArn' --output text | grep -q PendingConfirmation; then
  echo "   ⚠️  PendingConfirmation: open the 'AWS Notification - Subscription Confirmation' email and click"
  echo "      'Confirm subscription'. SNS will not deliver alerts until you do. Then run this script again."
  exit 1
fi
echo "   ✔ Confirmed (Status shows the subscription ARN)"

step "Publishing a test message"
aws sns publish --topic-arn "$TOPIC" \
  --subject "Cloud Monitoring Test" \
  --message "This is a test alert from Kwaku Digital Services. The AWS cloud monitoring notification system is working." \
  --query MessageId --output text | sed 's/^/   MessageId: /'

echo ""
echo "✅ Check your inbox for 'Cloud Monitoring Test'. This proves email delivery works."
echo "   Next: ./scripts/04-test-alarms.sh"
