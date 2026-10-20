# Testing results

Fill in **Result** and **Date** as you complete each test, and keep the matching evidence file (`evidence/`) or screenshot (`screenshots/`).

| # | Test | How | Expected | Result | Date |
|---|------|-----|----------|--------|------|
| 1 | Environment ready | `./scripts/00-check-prerequisites.sh` | Default VPC with a public subnet; template valid | | |
| 2 | Stack deployed | CloudFormation → Stacks | `CREATE_COMPLETE`, 9 resources | | |
| 3 | Website | Open `WebsiteURL` | Kwaku Digital Services page | | |
| 4 | No SSH exposure | EC2 → Security groups → `kwaku-monitoring-web-sg` | Only port 80 inbound | | |
| 5 | SNS subscription | SNS → Subscriptions | Status **Confirmed** | | |
| 6 | SNS delivery | `./scripts/03-test-sns.sh` | "Cloud Monitoring Test" email received | | |
| 7 | Alarms exist | CloudWatch → Alarms | CPU (60%, 2 × 5 min) and status check (2 × 1 min) | | |
| 8 | CPU alarm notification | `./scripts/04-test-alarms.sh` | ALARM email, then OK email | | |
| 9 | Status alarm notification | `./scripts/04-test-alarms.sh status` | ALARM email, then OK email | | |
| 10 | Budget | `./scripts/05-check-budget.sh` | $10 monthly, alerts at 80% actual and 100% forecasted | | |
| 11 | CloudTrail logging | `./scripts/06-check-cloudtrail.sh` | `IsLogging: True` | | |
| 12 | Audit events | CloudTrail → Event history | `RunInstances` / `CreateStack` with user and time | | |
| 13 | Audit storage | S3 audit bucket → `AWSLogs/` | Log files delivered | | |
| 14 | Bucket security | `06-check-cloudtrail.sh` output | Public access fully blocked; AES256 encryption | | |
| 15 | Cleanup | `./scripts/99-delete-stack.sh` | Stack deleted; no instance, alarms, topic, trail, budget or bucket left | | |

## Optional: test the CPU alarm with real load

The simulated test (8) proves the notification path. To trigger the alarm with real CPU usage you need a shell on the instance. The template deliberately opens no SSH port, so connect through **EC2 Instance Connect** after temporarily allowing SSH from the EC2 Instance Connect IP range, or attach an SSM role. Then run:

```bash
for i in $(seq $(nproc)); do timeout 15m sh -c 'while :; do :; done' & done
```

After about 10 minutes above 60% (two 5-minute periods), the alarm fires on its own. Remove the temporary access afterwards.

## Lessons learned (write your own)

- What failed the first time, and how did you find the cause (stack events, status reasons)?
- How long did each notification take to arrive?
- What would you add for production (see "Going further" in the README)?
