#!/usr/bin/env bash
# Phase 7: inspect the two CloudWatch alarms and test that they really email you.
#   ./scripts/04-test-alarms.sh            # show alarms + CPU metric, then simulate the CPU alarm
#   ./scripts/04-test-alarms.sh status     # simulate the status-check alarm instead
#   ./scripts/04-test-alarms.sh show       # only show alarms, metric and history
source "$(dirname "$0")/config.sh"
MODE="${1:-cpu}"
ID="$(out InstanceId)"
CPU_ALARM="$(out CpuAlarmName)"
STATUS_ALARM="$(out StatusCheckAlarmName)"

step "Alarms created by the stack"
aws cloudwatch describe-alarms --alarm-names "$CPU_ALARM" "$STATUS_ALARM" \
  --query 'MetricAlarms[].{Alarm:AlarmName, Metric:MetricName, Threshold:Threshold, Periods:EvaluationPeriods, Period:Period, State:StateValue}' \
  --output table

step "CPUUtilization of ${ID}, last hour (5-minute averages)"
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions "Name=InstanceId,Value=${ID}" --statistics Average --period 300 \
  --start-time "$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)" --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'sort_by(Datapoints, &Timestamp)[].{Time:Timestamp, AvgCPU:Average}' --output table

case "$MODE" in
  cpu)    TARGET="$CPU_ALARM" ;;
  status) TARGET="$STATUS_ALARM" ;;
  show)   TARGET="" ;;
  *) echo "usage: $0 [cpu|status|show]" >&2; exit 1 ;;
esac

if [[ -n "$TARGET" ]]; then
  step "Simulating ALARM on ${TARGET} (this sends the alert email through SNS)"
  aws cloudwatch set-alarm-state --alarm-name "$TARGET" \
    --state-value ALARM --state-reason "Testing CloudWatch notification"
  echo "   Done. CloudWatch returns the alarm to its real (metric-based) state at the next evaluation,"
  echo "   which sends a second 'OK' email."
  sleep 20
fi

step "Alarm history (newest first)"
aws cloudwatch describe-alarm-history --alarm-name "${TARGET:-$CPU_ALARM}" --history-item-type StateUpdate --max-records 5 \
  --query 'AlarmHistoryItems[].{Time:Timestamp, Change:HistorySummary}' --output table \
  || echo "   (alarm history not available right now: see CloudWatch → Alarms → History)"

echo ""
echo "This is a simulated test of the notification path, not proof of real high CPU."
echo "✅ Check your inbox for the ALARM email. Next: ./scripts/05-check-budget.sh"
