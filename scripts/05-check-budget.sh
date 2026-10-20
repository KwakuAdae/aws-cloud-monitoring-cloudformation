#!/usr/bin/env bash
# Phase 8: inspect the monthly cost budget and its email notifications.
source "$(dirname "$0")/config.sh"
ACCOUNT="$(account_id)"
BUDGET="$(out BudgetName)"

step "Budget ${BUDGET}"
aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$BUDGET" \
  --query 'Budget.{Name:BudgetName, Limit:BudgetLimit.Amount, Unit:BudgetLimit.Unit, Period:TimeUnit, ActualSpend:CalculatedSpend.ActualSpend.Amount, Forecast:CalculatedSpend.ForecastedSpend.Amount}' \
  --output table

step "Notifications"
aws budgets describe-notifications-for-budget --account-id "$ACCOUNT" --budget-name "$BUDGET" \
  --query 'Notifications[].{Type:NotificationType, When:ComparisonOperator, Threshold:Threshold, Unit:ThresholdType, State:NotificationState}' \
  --output table

LIMIT="$(aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$BUDGET" --query 'Budget.BudgetLimit.Amount' --output text)"
echo ""
echo "   You get an email when ACTUAL spend passes 80% of \$${LIMIT} (= \$$(python3 -c "print(round(${LIMIT} * 0.8, 2))")),"
echo "   and when AWS FORECASTS the month will end above \$${LIMIT}."
echo "   Budget data updates a few times a day. A budget is an alert, NOT a spending cap: nothing is stopped."
echo "✅ Next: ./scripts/06-check-cloudtrail.sh"
