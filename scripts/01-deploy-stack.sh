#!/usr/bin/env bash
# Phases 2-4: deploy the template as the stack kwaku-cloud-monitoring and watch it build (~3-5 minutes).
#   ALERT_EMAIL=you@example.com ./scripts/01-deploy-stack.sh
#   ALERT_EMAIL=you@example.com MONTHLY_BUDGET_USD=20 ./scripts/01-deploy-stack.sh   # other budget
# Running it again with changed values UPDATES the stack (CloudFormation works out the difference).
source "$(dirname "$0")/config.sh"
ALERT_EMAIL="${ALERT_EMAIL:-${1:-}}"
[[ -z "$ALERT_EMAIL" ]] && { echo "usage: ALERT_EMAIL=you@example.com $0" >&2; exit 1; }

step "Deploying stack ${STACK_NAME} from cloudformation/kwaku-monitoring.yaml"
echo "   AlertEmail=${ALERT_EMAIL}  MonthlyBudgetUSD=${MONTHLY_BUDGET_USD}  InstanceType=${INSTANCE_TYPE}"
# `deploy` creates a change set, executes it and waits for CREATE_COMPLETE / UPDATE_COMPLETE
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE" \
  --parameter-overrides \
      "AlertEmail=${ALERT_EMAIL}" \
      "MonthlyBudgetUSD=${MONTHLY_BUDGET_USD}" \
      "InstanceType=${INSTANCE_TYPE}" \
  --tags Project=kwaku-cloud-monitoring \
  --no-fail-on-empty-changeset || {
    echo ""
    echo "❌ Deployment failed. The first FAILED event is usually the real cause:"
    aws cloudformation describe-stack-events --stack-name "$STACK_NAME" \
      --query 'StackEvents[?contains(ResourceStatus, `FAILED`)].{Resource:LogicalResourceId, Status:ResourceStatus, Reason:ResourceStatusReason}' \
      --output table
    exit 1
  }

step "Stack status"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query 'Stacks[0].{Stack:StackName, Status:StackStatus, Created:CreationTime}' --output table

step "The 9 resources CloudFormation created"
aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" \
  --query 'StackResources[].{Logical:LogicalResourceId, Type:ResourceType, Status:ResourceStatus}' --output table

step "Outputs"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].{Key:OutputKey, Value:OutputValue}' --output table

echo ""
echo "✅ Deployed. Now:"
echo "   1. Confirm the 'AWS Notification - Subscription Confirmation' email sent to ${ALERT_EMAIL}"
echo "   2. ./scripts/02-test-website.sh"
