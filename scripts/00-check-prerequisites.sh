#!/usr/bin/env bash
# Phase 1: check the AWS environment before deploying.
#   identity and region · default VPC exists · a default subnet assigns public IPv4 · template is valid
source "$(dirname "$0")/config.sh"
PROBLEMS=0

step "Who am I, and which region?"
aws sts get-caller-identity --query '{Account:Account, Arn:Arn}' --output table
echo "   Region: ${AWS_REGION}"

step "Default VPC (the template launches the website into it)"
VPC_ID="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "   ❌ No default VPC in ${AWS_REGION}. Create one with:  aws ec2 create-default-vpc"
  PROBLEMS=$((PROBLEMS + 1))
else
  echo "   ✔ default VPC ${VPC_ID}"
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" Name=default-for-az,Values=true \
    --query 'Subnets[].{Subnet:SubnetId, AZ:AvailabilityZone, AutoPublicIP:MapPublicIpOnLaunch}' --output table
  PUBLIC="$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" Name=default-for-az,Values=true \
    --query 'length(Subnets[?MapPublicIpOnLaunch])' --output text)"
  if [[ "$PUBLIC" == "0" ]]; then
    echo "   ❌ No default subnet assigns public IPv4 addresses: the website would not be reachable."
    PROBLEMS=$((PROBLEMS + 1))
  else
    echo "   ✔ ${PUBLIC} default subnet(s) assign public IPv4 addresses"
  fi
fi

step "Existing trails (CloudTrail allows 5 per region)"
aws cloudtrail describe-trails --query 'trailList[].{Name:Name, HomeRegion:HomeRegion, MultiRegion:IsMultiRegionTrail}' --output table

step "Validating the CloudFormation template"
if aws cloudformation validate-template --template-body "file://${TEMPLATE}" >/dev/null; then
  echo "   ✔ template is valid. Parameters: $(aws cloudformation validate-template --template-body "file://${TEMPLATE}" \
    --query 'Parameters[].ParameterKey' --output text | tr '\t' ' ')"
else
  PROBLEMS=$((PROBLEMS + 1))
fi
echo ""
if [[ "$PROBLEMS" -eq 0 ]]; then
  echo "✅ Ready. Next: ALERT_EMAIL=you@example.com ./scripts/01-deploy-stack.sh"
else
  echo "⚠️  Fix the ${PROBLEMS} problem(s) above before deploying."
  exit 1
fi
