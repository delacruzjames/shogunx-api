#!/usr/bin/env bash
# Substitute deploy/aws/env.example variables into task-definition.json for registration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${ECS_EXECUTION_ROLE_ARN:?Set ECS_EXECUTION_ROLE_ARN}"
: "${ECS_TASK_ROLE_ARN:?Set ECS_TASK_ROLE_ARN}"
: "${SECRET_RAILS_MASTER_KEY_ARN:?Set SECRET_RAILS_MASTER_KEY_ARN}"
: "${SECRET_DATABASE_URL_ARN:?Set SECRET_DATABASE_URL_ARN}"
: "${SECRET_OPENAI_API_KEY_ARN:?Set SECRET_OPENAI_API_KEY_ARN}"
: "${SECRET_SHOGUNX_API_KEY_ARN:?Set SECRET_SHOGUNX_API_KEY_ARN}"

IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY:-shogunx-api}:${IMAGE_TAG}"

sed \
  -e "s|ECS_EXECUTION_ROLE_ARN|${ECS_EXECUTION_ROLE_ARN}|g" \
  -e "s|ECS_TASK_ROLE_ARN|${ECS_TASK_ROLE_ARN}|g" \
  -e "s|AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/shogunx-api:latest|${IMAGE}|g" \
  -e "s|AWS_REGION|${AWS_REGION}|g" \
  -e "s|SECRET_RAILS_MASTER_KEY_ARN|${SECRET_RAILS_MASTER_KEY_ARN}|g" \
  -e "s|SECRET_DATABASE_URL_ARN|${SECRET_DATABASE_URL_ARN}|g" \
  -e "s|SECRET_OPENAI_API_KEY_ARN|${SECRET_OPENAI_API_KEY_ARN}|g" \
  -e "s|SECRET_SHOGUNX_API_KEY_ARN|${SECRET_SHOGUNX_API_KEY_ARN}|g" \
  "${SCRIPT_DIR}/task-definition.json"
