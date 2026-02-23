#!/usr/bin/env bash
# Deploy the auth server to AWS Lambda + API Gateway HTTP API
set -euo pipefail

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# ── Config ────────────────────────────────────────────────────────────────────
FUNCTION_NAME="my-test-repo-auth"
API_NAME="my-test-repo-api"
ROLE_NAME="my-test-repo-lambda-role"
REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
RUNTIME="nodejs20.x"
HANDLER="server.handler"
TIMEOUT=30
MEMORY=256
ZIP_FILE="function.zip"

echo ""
echo "=== Deploying $FUNCTION_NAME to Lambda + API Gateway ($REGION) ==="
echo ""

# ── Step 1: IAM role ──────────────────────────────────────────────────────────
echo "1/5  Checking IAM role..."

# Use LAMBDA_ROLE_ARN from .env if set (pre-created manually in AWS Console)
if [ -n "${LAMBDA_ROLE_ARN:-}" ]; then
  ROLE_ARN="$LAMBDA_ROLE_ARN"
  echo "     Using pre-configured role: $ROLE_ARN"
else
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null || true)

  if [ -z "$ROLE_ARN" ]; then
    echo "     Creating role $ROLE_NAME..."
    ROLE_ARN=$(aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document '{
        "Version":"2012-10-17",
        "Statement":[{
          "Effect":"Allow",
          "Principal":{"Service":"lambda.amazonaws.com"},
          "Action":"sts:AssumeRole"
        }]
      }' \
      --query 'Role.Arn' --output text)

    aws iam attach-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

    TABLE_ARN="arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${DYNAMODB_TABLE}"
    aws iam put-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-name "DynamoDB-${DYNAMODB_TABLE}-only" \
      --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
          \"Effect\": \"Allow\",
          \"Action\": [
            \"dynamodb:DescribeTable\",
            \"dynamodb:CreateTable\",
            \"dynamodb:GetItem\",
            \"dynamodb:PutItem\"
          ],
          \"Resource\": \"${TABLE_ARN}\"
        }]
      }"

    echo "     Waiting 10s for role to propagate..."
    sleep 10
  fi
fi
echo "     Role ARN: $ROLE_ARN"

# ── Step 2: Zip deployment package ───────────────────────────────────────────
echo "2/5  Building deployment package..."
rm -f "$ZIP_FILE"
zip -qr "$ZIP_FILE" . \
  --exclude ".env" \
  --exclude ".env.example" \
  --exclude ".gitignore" \
  --exclude "deploy.sh" \
  --exclude "$ZIP_FILE" \
  --exclude "*.sh"
echo "     Package size: $(du -sh $ZIP_FILE | cut -f1)"

# ── Step 3: Create or update Lambda function ──────────────────────────────────
echo "3/5  Deploying Lambda function..."
FUNCTION_EXISTS=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'Configuration.FunctionName' \
  --output text 2>/dev/null || true)

ENV_VARS="Variables={JWT_SECRET=$JWT_SECRET,DYNAMODB_TABLE=$DYNAMODB_TABLE}"

if [ -z "$FUNCTION_EXISTS" ]; then
  echo "     Creating function (first deploy)..."
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime "$RUNTIME" \
    --handler "$HANDLER" \
    --role "$ROLE_ARN" \
    --zip-file "fileb://$ZIP_FILE" \
    --timeout "$TIMEOUT" \
    --memory-size "$MEMORY" \
    --environment "$ENV_VARS" \
    --region "$REGION" \
    --output text > /dev/null

  echo "     Waiting for function to be active..."
  aws lambda wait function-active \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"
else
  echo "     Updating existing function..."
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --region "$REGION" \
    --output text > /dev/null

  aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$ENV_VARS" \
    --region "$REGION" \
    --output text > /dev/null
fi
echo "     Function deployed."
rm -f "$ZIP_FILE"

# ── Step 4: API Gateway HTTP API ──────────────────────────────────────────────
echo "4/5  Configuring API Gateway..."
FUNC_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

# Check if API already exists
API_ID=$(aws apigatewayv2 get-apis \
  --region "$REGION" \
  --query "Items[?Name=='$API_NAME'].ApiId" \
  --output text 2>/dev/null || true)

if [ -z "$API_ID" ]; then
  echo "     Creating HTTP API..."
  API_ID=$(aws apigatewayv2 create-api \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --cors-configuration 'AllowOrigins=["*"],AllowMethods=["GET","POST","DELETE","OPTIONS"],AllowHeaders=["content-type","authorization"]' \
    --region "$REGION" \
    --query 'ApiId' --output text)

  echo "     Creating Lambda integration..."
  INTEG_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$FUNC_ARN" \
    --payload-format-version "2.0" \
    --region "$REGION" \
    --query 'IntegrationId' --output text)

  echo "     Creating catch-all route..."
  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "\$default" \
    --target "integrations/$INTEG_ID" \
    --region "$REGION" --output text > /dev/null

  echo "     Deploying stage..."
  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name '$default' \
    --auto-deploy \
    --region "$REGION" --output text > /dev/null

  echo "     Granting API Gateway permission to invoke Lambda..."
  aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id apigw-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*" \
    --region "$REGION" --output text > /dev/null
else
  echo "     API already exists (ID: $API_ID) — updating CORS and adding catch-all route..."

  # Update CORS to allow GET, POST, DELETE and the Authorization header
  aws apigatewayv2 update-api \
    --api-id "$API_ID" \
    --cors-configuration 'AllowOrigins=["*"],AllowMethods=["GET","POST","DELETE","OPTIONS"],AllowHeaders=["content-type","authorization"]' \
    --region "$REGION" --output text > /dev/null

  # Get the existing integration ID
  INTEG_ID=$(aws apigatewayv2 get-integrations \
    --api-id "$API_ID" \
    --region "$REGION" \
    --query 'Items[0].IntegrationId' --output text)

  # Add catch-all $default route if it doesn't exist
  EXISTING_DEFAULT=$(aws apigatewayv2 get-routes \
    --api-id "$API_ID" \
    --region "$REGION" \
    --query "Items[?RouteKey=='\$default'].RouteId" --output text)

  if [ -z "$EXISTING_DEFAULT" ]; then
    aws apigatewayv2 create-route \
      --api-id "$API_ID" \
      --route-key "\$default" \
      --target "integrations/$INTEG_ID" \
      --region "$REGION" --output text > /dev/null
    echo "     Catch-all route added."
  else
    echo "     Catch-all route already exists."
  fi
fi

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
echo "     API URL: $API_URL"

# ── Step 5: Update config.js and upload to S3 ────────────────────────────────
echo "5/5  Updating ../config.js and uploading to S3..."
CONFIG_FILE="../config.js"
cat > "$CONFIG_FILE" <<EOF
// Auto-generated by deploy.sh — do not edit manually
window.API_BASE = '$API_URL';
EOF

aws s3 cp "$CONFIG_FILE" "s3://${S3_BUCKET:-sajeedmoh-my-projects}/config.js" \
  --content-type "application/javascript" \
  --region "$REGION"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Deploy complete ==="
echo ""
echo "  API Gateway URL : $API_URL"
echo "  S3 login page   : http://${S3_BUCKET:-sajeedmoh-my-projects}.s3-website.${REGION}.amazonaws.com/login.html"
echo ""
echo "  Endpoints:"
echo "    POST   $API_URL/api/auth/register"
echo "    POST   $API_URL/api/auth/login"
echo "    GET    $API_URL/api/electricity"
echo "    POST   $API_URL/api/electricity"
echo "    DELETE $API_URL/api/electricity/:id"
echo ""
