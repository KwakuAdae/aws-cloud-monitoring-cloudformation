#!/usr/bin/env bash
# Shared settings for every script. Override any value by exporting it before running a script.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-eu-west-2}"          # Europe (London)
export AWS_DEFAULT_REGION="$AWS_REGION"
export STACK_NAME="${STACK_NAME:-kwaku-cloud-monitoring}"
export MONTHLY_BUDGET_USD="${MONTHLY_BUDGET_USD:-10}"
export INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/cloudformation/kwaku-monitoring.yaml"

# Read one output of the deployed stack:  out WebsiteURL
out() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

account_id() { aws sts get-caller-identity --query Account --output text; }

step() { echo ""; echo "▶ $*"; }
