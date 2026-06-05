#!/usr/bin/env bash
# Build, push, register task definition, migrate, and roll out the ECS service.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${ECS_CLUSTER:?Set ECS_CLUSTER}"
: "${ECS_SERVICE:?Set ECS_SERVICE}"

IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "==> Build and push image"
IMAGE_TAG="$IMAGE_TAG" "$SCRIPT_DIR/build-and-push.sh"

echo "==> Register task definition"
RENDERED_TASK_DEF="$(mktemp)"
"$SCRIPT_DIR/render-task-definition.sh" > "$RENDERED_TASK_DEF"
TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json "file://${RENDERED_TASK_DEF}" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)
rm -f "$RENDERED_TASK_DEF"
echo "Registered ${TASK_DEF_ARN}"

echo "==> Run migrations"
"$SCRIPT_DIR/migrate.sh"

echo "==> Update ECS service"
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "$TASK_DEF_ARN" \
  --force-new-deployment \
  --region "$AWS_REGION" \
  --query 'service.serviceName' \
  --output text

echo "==> Wait for service stability"
aws ecs wait services-stable \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION"

echo "Deploy complete."
