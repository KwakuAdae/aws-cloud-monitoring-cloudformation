# Troubleshooting

## The stack fails to create (`ROLLBACK_COMPLETE`)

Open **CloudFormation → kwaku-cloud-monitoring → Events** and read the **first** `CREATE_FAILED` event (later failures are usually "Resource creation cancelled"). Or:

```bash
aws cloudformation describe-stack-events --stack-name kwaku-cloud-monitoring \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].{Resource:LogicalResourceId, Reason:ResourceStatusReason}' --output table
```

A stack in `ROLLBACK_COMPLETE` cannot be updated: delete it (`./scripts/99-delete-stack.sh`) and deploy again.

| Failed resource | Typical reason | Fix |
|-----------------|----------------|-----|
| `WebServer` | `No default VPC for this user` / `VPCIdNotSpecified` | `aws ec2 create-default-vpc`, or change the template to use your own subnet |
| `WebServer` | `The requested configuration is currently not supported` | Pick another instance type (`t3.small`) |
| `AuditBucket` | `kwaku-audit-logs-... already exists` | A previous stack's bucket was kept. Empty and delete it in S3, then redeploy |
| `AuditTrail` | `Insufficient permissions to access S3 bucket` | The bucket policy must exist first (the template has `DependsOn`); check it was not edited |
| `AuditTrail` | `Trail kwaku-monitoring-trail already exists` | Delete the old trail, or rename it in the template and bucket policy |
| `AuditTrail` | `maximum number of trails` | 5 trails per region: delete an unused one |
| `MonthlyBudget` | `DuplicateRecordException` | A budget with that name exists (budgets are account-wide). Delete it in Budgets |
| `MonthlyBudget` | `AccessDenied` | Budgets permissions are needed (`budgets:*` on the account); on a member account, billing access must be enabled by the payer |
| `AlertTopic` | `Invalid parameter: Email address` | Fix `AlertEmail` |
| any | `is not authorized to perform` | Your identity is missing that permission |

## Website does not load

| Check | Fix |
|-------|-----|
| EC2 → instance state | Must be `running` with **status checks 2/2 passed** |
| Public IPv4 address | The default subnet must auto-assign public IPs (Phase 1) |
| Just created? | NGINX installs in 1-2 minutes after boot |
| Browser forces HTTPS | Type `http://` explicitly: there is no HTTPS listener |
| Still failing | EC2 → instance → **Actions → Monitor and troubleshoot → Get system log**: look for `nginx` and cloud-init errors |

## No emails

| Symptom | Fix |
|---------|-----|
| Subscription `PendingConfirmation` | Click the link in the confirmation email (check spam). Subscriptions expire after 3 days unconfirmed: redeploy, or SNS → Create subscription |
| Test publish works, alarm emails do not | The alarm must actually change state. `set-alarm-state` to `ALARM` only sends if it was not already in ALARM |
| No budget email | Budgets update a few times a day and email only when spending crosses the threshold. A brand-new account may show $0 for a while |

## Alarms

| Symptom | Meaning |
|---------|---------|
| Alarm shows `INSUFFICIENT_DATA` | Normal right after creation, before the first datapoints (5-10 minutes for the CPU alarm) |
| CPU alarm returns to OK right after the test | Expected: `set-alarm-state` is temporary. CloudWatch re-evaluates the real metric |
| Status-check alarm never changes | Status checks pass on a healthy instance. Use `./scripts/04-test-alarms.sh status` to simulate |

## CloudTrail

| Symptom | Fix |
|---------|-----|
| No files in `AWSLogs/` | First delivery takes 5-15 minutes. `aws cloudtrail get-trail-status --name kwaku-monitoring-trail` shows `LatestDeliveryError` if the bucket policy is wrong |
| Event history empty for an event | Event history covers the last 90 days of management events in this region. Global events (IAM) appear in us-east-1 |

## Deleting the stack

| Symptom | Fix |
|---------|-----|
| `DELETE_FAILED` on `AuditBucket`: *The bucket you tried to delete is not empty* | CloudTrail delivered more logs. Empty the bucket (S3 → **Empty**) and delete the stack again. `99-delete-stack.sh` does this automatically |
| Budget still listed | It is deleted with the stack. If you created one manually, delete it in Budgets |
| Charges after deletion | Charges already incurred remain. Check **Billing → Bills** the next day |
