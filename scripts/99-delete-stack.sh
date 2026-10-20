#!/usr/bin/env bash
# Phase 12: delete everything the stack created.
# A non-empty S3 bucket cannot be deleted, so: stop CloudTrail logging → empty the bucket →
# delete the stack → if the bucket received late log files, empty it again and retry.
source "$(dirname "$0")/config.sh"

if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
  echo "Stack ${STACK_NAME} does not exist. Nothing to delete."
  exit 0
fi
BUCKET="$(out AuditBucketName)"
TRAIL="$(out TrailName)"

empty_bucket() {
  aws s3 rm "s3://${BUCKET}" --recursive --only-show-errors 2>/dev/null || true
}

step "Stopping CloudTrail logging (so no new files arrive while we clean up)"
aws cloudtrail stop-logging --name "$TRAIL" 2>/dev/null && echo "   stopped ${TRAIL}"

step "Emptying s3://${BUCKET} (the audit logs are deleted: keep a copy first if you need them)"
empty_bucket

for attempt in 1 2 3; do
  step "Deleting stack ${STACK_NAME} (attempt ${attempt})"
  aws cloudformation delete-stack --stack-name "$STACK_NAME"
  if aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" 2>/dev/null; then
    echo ""
    echo "✅ Stack deleted: EC2 instance, security group, SNS topic, alarms, budget, trail, bucket and policy."
    echo "   Check EC2, CloudWatch, SNS, CloudTrail, Budgets and S3, and review Billing for remaining charges."
    exit 0
  fi
  echo "   Delete did not complete. Reason:"
  aws cloudformation describe-stack-events --stack-name "$STACK_NAME" \
    --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`]|[0:3].{Resource:LogicalResourceId, Reason:ResourceStatusReason}' \
    --output table
  echo "   Emptying the bucket again (late CloudTrail deliveries) and retrying..."
  empty_bucket
  sleep 10
done

echo "❌ Could not delete the stack. Open CloudFormation → ${STACK_NAME} → Events for details." >&2
exit 1
