#!/usr/bin/env bash
set -euo pipefail

: "${NPP_RUNTIME_DIR:?NPP_RUNTIME_DIR is required}"
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${RUNTIME_CONFIG:?RUNTIME_CONFIG is required}"
: "${MCP_RUNTIME_API_BASE_URL:?MCP_RUNTIME_API_BASE_URL is required}"
: "${MCP_RUNTIME_RUN_ID:?MCP_RUNTIME_RUN_ID is required}"

INSTALLATION_ID="e2e-installation"
EMPLOYEE_ID="91111111-1111-4111-8111-111111111111"
USER_ID="92222222-2222-4222-8222-222222222222"
WAREHOUSE_ID="94444444-4444-4444-8444-444444444444"
CUSTOMER_ID="95555555-5555-4555-8555-555555555555"
CUSTOMER_ADDRESS_ID="96666666-6666-4666-8666-666666666666"
VARIANT_ID="99999999-9999-4999-8999-999999999999"
LOGIN_NAME="e2e.workforce"
R2_BUCKET="mcp-l7-runtime"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_ROOT="${RUNNER_TEMP:-$WORKSPACE/.runtime}"
LOG_DIR="$RUNTIME_ROOT/logs"
PY_ENV="$RUNTIME_ROOT/python"
mkdir -p "$LOG_DIR"

random_value() {
  python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
}

WORKFORCE_PASSWORD="E2E-$(random_value)-Aa9!"
CORE_BACKEND_TOKEN="$(random_value)"
ONBOARDING_TOKEN="$(random_value)"
SALES_TOKEN="$(random_value)"
MCP_BACKEND_TOKEN="$(random_value)"
REPORT_AGENT_TOKEN="$(random_value)"
R2_ACCESS_KEY="L7$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
R2_SECRET_KEY="$(random_value)"

for value in "$WORKFORCE_PASSWORD" "$CORE_BACKEND_TOKEN" "$ONBOARDING_TOKEN" \
  "$SALES_TOKEN" "$MCP_BACKEND_TOKEN" "$REPORT_AGENT_TOKEN" \
  "$R2_ACCESS_KEY" "$R2_SECRET_KEY"; do
  echo "::add-mask::$value"
done

wait_http() {
  local url="$1"
  local attempts="${2:-90}"
  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  echo "Runtime service did not become ready: $url" >&2
  return 1
}

echo "Applying Công Ty migrations to isolated test database..."
(
  cd "$NPP_RUNTIME_DIR"
  NODE_ENV=test \
  DATABASE_URL="$DATABASE_URL" \
  DATABASE_SSL_MODE=disable \
  npm --workspace npp-core-api run migration:migrate
)

echo "Applying MCP migrations to isolated test database..."
(
  cd "$NPP_RUNTIME_DIR"
  NODE_ENV=test \
  DATABASE_URL="$DATABASE_URL" \
  MCP_DB_SCHEMA=mcp \
  npm --workspace mcp/apps/backend run migration:migrate
)

echo "Preparing workforce and commercial fixtures..."
(
  cd "$NPP_RUNTIME_DIR"
  NODE_ENV=test \
  DATABASE_URL="$DATABASE_URL" \
  DATABASE_SSL_MODE=disable \
  INSTALLATION_ID="$INSTALLATION_ID" \
  E2E_WORKFORCE_EMPLOYEE_ID="$EMPLOYEE_ID" \
  E2E_WORKFORCE_USER_ID="$USER_ID" \
  E2E_WORKFORCE_LOGIN="$LOGIN_NAME" \
  E2E_WORKFORCE_PASSWORD="$WORKFORCE_PASSWORD" \
  node npp-core/api/scripts/prepare-workforce-e2e.js

  NODE_ENV=test \
  DATABASE_URL="$DATABASE_URL" \
  DATABASE_SSL_MODE=disable \
  INSTALLATION_ID="$INSTALLATION_ID" \
  node npp-core/api/scripts/prepare-mcp-mobile-runtime-e2e.js
)

echo "Starting local S3-compatible object storage..."
python3 -m venv "$PY_ENV"
"$PY_ENV/bin/python" -m pip install --disable-pip-version-check --quiet \
  'moto[server]>=5,<6' boto3
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
"$PY_ENV/bin/moto_server" -H 127.0.0.1 -p 9000 >"$LOG_DIR/object-storage.log" 2>&1 &
echo "$!" >>"$RUNTIME_ROOT/pids"
wait_http "http://127.0.0.1:9000/" 60 || true
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
"$PY_ENV/bin/python" - <<PY
import boto3
client = boto3.client(
    "s3",
    endpoint_url="http://127.0.0.1:9000",
    region_name="us-east-1",
)
try:
    client.create_bucket(Bucket="$R2_BUCKET")
except client.exceptions.BucketAlreadyOwnedByYou:
    pass
client.head_bucket(Bucket="$R2_BUCKET")
PY

echo "Starting deterministic report-analysis adapter..."
REPORT_AGENT_HOST=127.0.0.1 \
REPORT_AGENT_PORT=4010 \
REPORT_AGENT_TOKEN="$REPORT_AGENT_TOKEN" \
node "$SCRIPT_DIR/report_agent_test_server.mjs" >"$LOG_DIR/report-agent.log" 2>&1 &
echo "$!" >>"$RUNTIME_ROOT/pids"
wait_http "http://127.0.0.1:4010/health" 30

echo "Starting Công Ty API..."
(
  cd "$NPP_RUNTIME_DIR"
  env \
    NODE_ENV=test \
    HOST=127.0.0.1 \
    PORT=3004 \
    INSTALLATION_ID="$INSTALLATION_ID" \
    DATABASE_URL="$DATABASE_URL" \
    DATABASE_SSL_MODE=disable \
    BACKEND_API_TOKEN="$CORE_BACKEND_TOKEN" \
    CORE_BOOTSTRAP_ACTOR_ID=bootstrap:e2e \
    CORS_ORIGINS=http://127.0.0.1:3001 \
    R2_ENABLED=false \
    R2_CONTRACT_ROUTE_ENABLED=false \
    INTERNAL_AUTH_ENABLED=true \
    INTERNAL_SESSION_TTL_SECONDS=3600 \
    INTERNAL_WEB_OWNER_CHALLENGE_REQUIRED=false \
    ALLOW_FIXED_OWNER_CODE=false \
    MCP_ONBOARDING_API_TOKEN="$ONBOARDING_TOKEN" \
    MCP_ONBOARDING_ACTOR_ID=service:mcp-customer-onboarding \
    MCP_SALES_API_TOKEN="$SALES_TOKEN" \
    MCP_SALES_ACTOR_ID=service:mcp-sales-order \
    MCP_SALES_WAREHOUSE_IDS="$WAREHOUSE_ID" \
    npm --workspace npp-core-api run start
) >"$LOG_DIR/company-api.log" 2>&1 &
echo "$!" >>"$RUNTIME_ROOT/pids"
wait_http "http://127.0.0.1:3004/health/live" 90

echo "Starting MCP API..."
(
  cd "$NPP_RUNTIME_DIR"
  env \
    NODE_ENV=test \
    SERVICE_NAME=mcp-plan-backend \
    HOST=0.0.0.0 \
    PORT=3001 \
    LEGACY_INTERNAL_PORT=3002 \
    INSTALLATION_ID="$INSTALLATION_ID" \
    NPP_CODE=e2e \
    MCP_LEGACY_ACTOR_ID=service:e2e:mcp-v1 \
    AUTH_MODE=proxy-service \
    BACKEND_API_TOKEN="$MCP_BACKEND_TOKEN" \
    CORE_AUTH_API_BASE_URL=http://127.0.0.1:3004 \
    CORE_AUTH_TIMEOUT_MS=8000 \
    CORE_ONBOARDING_API_BASE_URL=http://127.0.0.1:3004 \
    CORE_ONBOARDING_API_TOKEN="$ONBOARDING_TOKEN" \
    CORE_ONBOARDING_TIMEOUT_MS=15000 \
    CORE_SALES_API_BASE_URL=http://127.0.0.1:3004 \
    CORE_SALES_API_TOKEN="$SALES_TOKEN" \
    CORE_SALES_DEFAULT_WAREHOUSE_ID="$WAREHOUSE_ID" \
    CORE_SALES_TIMEOUT_MS=15000 \
    MCP_REPORT_AGENT_URL=http://127.0.0.1:4010/analyze \
    MCP_REPORT_AGENT_TOKEN="$REPORT_AGENT_TOKEN" \
    MCP_REPORT_AGENT_TIMEOUT_MS=15000 \
    MCP_SERVICE_PERMISSIONS=mcp.route.write,mcp.route-customer.write,mcp.session.write,mcp.session-customer.write,mcp.order.write,mcp.test.write,mcp.report.write,mcp.followup.write,mcp.report-setting.write,mcp.sales-order.read,mcp.sales-order.create \
    MCP_SERVICE_SCOPES="mcp:warehouse:$WAREHOUSE_ID" \
    PERSISTENCE_PROVIDER=postgresql \
    DATABASE_URL="$DATABASE_URL" \
    MCP_DB_SCHEMA=mcp \
    MCP_DB_POOL_MAX=5 \
    MCP_DB_CONNECT_TIMEOUT_MS=5000 \
    MCP_DB_IDLE_TIMEOUT_MS=30000 \
    MCP_DB_STATEMENT_TIMEOUT_MS=15000 \
    MCP_LEGACY_RUNTIME_ENABLED=false \
    CORS_ORIGINS=http://127.0.0.1:3001 \
    UPSTREAM_TIMEOUT_MS=30000 \
    R2_BUCKET_NAME="$R2_BUCKET" \
    R2_ENDPOINT=http://127.0.0.1:9000 \
    R2_REGION=us-east-1 \
    R2_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
    R2_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
    npm --workspace mcp/apps/backend run start
) >"$LOG_DIR/mcp-api.log" 2>&1 &
echo "$!" >>"$RUNTIME_ROOT/pids"

wait_http "http://127.0.0.1:3001/health/live" 90
wait_http "http://127.0.0.1:3001/health/ready" 90

python3 - <<PY
import json, os
payload = {
    "MCP_RUNTIME_GUARD": "APPROVED_TEST_INSTALLATION_ONLY",
    "MCP_RUNTIME_ENVIRONMENT": "test-local-ci",
    "MCP_RUNTIME_API_BASE_URL": os.environ["MCP_RUNTIME_API_BASE_URL"],
    "MCP_RUNTIME_LOGIN_NAME": "$LOGIN_NAME",
    "MCP_RUNTIME_PASSWORD": "$WORKFORCE_PASSWORD",
    "MCP_RUNTIME_OWNER_CODE": "",
    "MCP_RUNTIME_ORDER_CUSTOMER_ID": "$CUSTOMER_ID",
    "MCP_RUNTIME_ORDER_CUSTOMER_ADDRESS_ID": "$CUSTOMER_ADDRESS_ID",
    "MCP_RUNTIME_ORDER_VARIANT_ID": "$VARIANT_ID",
    "MCP_RUNTIME_RUN_ID": os.environ["MCP_RUNTIME_RUN_ID"],
}
with open(os.environ["RUNTIME_CONFIG"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
os.chmod(os.environ["RUNTIME_CONFIG"], 0o600)
PY

echo "Self-contained MCP mobile test installation is ready."
