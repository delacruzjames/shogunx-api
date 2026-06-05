#!/usr/bin/env bash
# Run database migrations as a one-off Fargate task (best practice before rolling out web).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${AWS_REGION:?Set AWS_REGION}"
: "${ECS_CLUSTER:?Set ECS_CLUSTER}"
: "${ECS_TASK_DEFINITION_FAMILY:?Set ECS_TASK_DEFINITION_FAMILY}"
: "${ECS_SUBNETS:?Set ECS_SUBNETS (comma-separated)}"
: "${ECS_SECURITY_GROUPS:?Set ECS_SECURITY_GROUPS (comma-separated)}"

TASK_DEF=$(aws ecs describe-task-definition \
  --task-definition "$ECS_TASK_DEFINITION_FAMILY" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

SUBNETS_JSON=$(echo "$ECS_SUBNETS" | awk -F, '{printf "["; for (i=1; i<=NF; i++) {gsub(/^ +| +$/, "", $i); printf "\"%s\"%s", $i, (i<NF ? "," : "")}; printf "]"}')
SGS_JSON=$(echo "$ECS_SECURITY_GROUPS" | awk -F, '{printf "["; for (i=1; i<=NF; i++) {gsub(/^ +| +$/, "", $i); printf "\"%s\"%s", $i, (i<NF ? "," : "")}; printf "]"}')

echo "==> Running db:prepare on ${TASK_DEF}"
TASK_ARN=$(aws ecs run-task \
  --cluster "$ECS_CLUSTER" \
  --task-definition "$TASK_DEF" \
  --launch-type FARGATE \
  --region "$AWS_REGION" \
  --network-configuration "awsvpcConfiguration={subnets=${SUBNETS_JSON},securityGroups=${SGS_JSON},assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"web","command":["./bin/rails","db:prepare"]}]}' \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Task started: ${TASK_ARN}"
echo "Waiting for task to complete..."
aws ecs wait tasks-stopped --cluster "$ECS_CLUSTER" --tasks "$TASK_ARN" --region "$AWS_REGION"

EXIT_CODE=$(aws ecs describe-tasks \
  --cluster "$ECS_CLUSTER" \
  --tasks "$TASK_ARN" \
  --region "$AWS_REGION" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)

if [ "$EXIT_CODE" != "0" ]; then
  echo "Migration failed with exit code ${EXIT_CODE}. Check CloudWatch: /ecs/shogunx-api"
  exit 1
fi

echo "Migrations completed successfully."
