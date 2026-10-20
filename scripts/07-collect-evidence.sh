#!/usr/bin/env bash
# Phase 10-11: save proof that each business problem is solved into evidence/ (commit it with
# your screenshots). No credentials are written; account IDs are masked.
source "$(dirname "$0")/config.sh"
OUT="${ROOT_DIR}/evidence"
mkdir -p "$OUT"
ACCOUNT="$(account_id)"

run() {   # run FILE COMMAND...: save a command and its output, with the account ID masked
  local file="$OUT/$1"; shift
  { echo "\$ $*"; echo; "$@" 2>&1 || echo "(command failed: see the message above)"; } \
    | sed "s/${ACCOUNT}/<account-id>/g" > "$file"
  echo "   wrote evidence/$(basename "$file")"
}

step "Collecting evidence ($(date -u '+%Y-%m-%d %H:%M UTC'))"
run 01-stack.txt aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query 'Stacks[0].{Stack:StackName, Status:StackStatus, Created:CreationTime, Outputs:Outputs}' --output json
run 02-stack-resources.txt aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" \
  --query 'StackResources[].{Logical:LogicalResourceId, Type:ResourceType, Status:ResourceStatus}' --output table
run 03-ec2-instance.txt aws ec2 describe-instances --instance-ids "$(out InstanceId)" \
  --query 'Reservations[0].Instances[0].{State:State.Name, Type:InstanceType, AZ:Placement.AvailabilityZone}' --output table
run 04-alarms.txt aws cloudwatch describe-alarms --alarm-names "$(out CpuAlarmName)" "$(out StatusCheckAlarmName)" \
  --query 'MetricAlarms[].{Alarm:AlarmName, Metric:MetricName, Threshold:Threshold, State:StateValue}' --output table
run 05-alarm-history.txt aws cloudwatch describe-alarm-history --alarm-name "$(out CpuAlarmName)" \
  --history-item-type StateUpdate --max-records 10 --query 'AlarmHistoryItems[].{Time:Timestamp, Change:HistorySummary}' --output table
run 06-sns-subscription.txt aws sns list-subscriptions-by-topic --topic-arn "$(out SNSTopicArn)" \
  --query 'Subscriptions[].{Protocol:Protocol, Status:SubscriptionArn}' --output table
run 07-budget.txt aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$(out BudgetName)" \
  --query 'Budget.{Name:BudgetName, Limit:BudgetLimit, Period:TimeUnit, Spend:CalculatedSpend}' --output json
run 08-budget-notifications.txt aws budgets describe-notifications-for-budget --account-id "$ACCOUNT" \
  --budget-name "$(out BudgetName)" --output table
run 09-cloudtrail-status.txt aws cloudtrail get-trail-status --name "$(out TrailName)" --output table
run 10-cloudtrail-events.txt aws cloudtrail lookup-events --max-results 10 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$STACK_NAME" \
  --query 'Events[].{Time:EventTime, Event:EventName, User:Username}' --output table
run 11-audit-bucket.txt aws s3api list-objects-v2 --bucket "$(out AuditBucketName)" --prefix AWSLogs/ --max-items 10 \
  --query 'Contents[].{Key:Key, Size:Size}' --output table
{
  echo "\$ curl -s $(out WebsiteURL)"; echo
  curl -s --max-time 10 "$(out WebsiteURL)" | grep -oE '<h1>[^<]+</h1>|<p>Business[^<]+</p>' | sed 's/<[^>]*>//g'
} > "$OUT/12-website.txt"
echo "   wrote evidence/12-website.txt"

echo ""
echo "✅ Evidence saved in evidence/. Add your screenshots to screenshots/ and commit both."
