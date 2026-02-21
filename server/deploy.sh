#!/usr/bin/env bash
# Deploy the auth server to AWS Lambda with a Function URL
set -euo pipefail

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# ── Config ────────────────────────────────────────────────────────────────────
FUNCTION_NAME="my-test-repo-auth"
ROLE_NAME="my-test-repo-lambda-role"
REGION="${AWS_REGION:-ap-south-1}"
RUNTIME="nodejs20.x"
HANDLER="server.handler"
TIMEOUT=30
MEMORY=256
ZIP_FILE="function.zip"

echo ""
echo "=== Deploying $FUNCTION_NAME to Lambda ($REGION) ==="
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

    aws iam attach-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

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

# ── Step 4: Function URL with CORS ────────────────────────────────────────────
echo "4/5  Configuring Function URL..."
FUNC_URL=$(aws lambda get-function-url-config \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'FunctionUrl' --output text 2>/dev/null || true)

if [ -z "$FUNC_URL" ]; then
  # Allow public invocation
  aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region "$REGION" \
    --output text > /dev/null

  FUNC_URL=$(aws lambda create-function-url-config \
    --function-name "$FUNCTION_NAME" \
    --auth-type NONE \
    --cors '{
      "AllowOrigins":["*"],
      "AllowMethods":["POST"],
      "AllowHeaders":["Content-Type"]
    }' \
    --region "$REGION" \
    --query 'FunctionUrl' --output text)
fi

# Strip trailing slash
FUNC_URL="${FUNC_URL%/}"
echo "     Function URL: $FUNC_URL"

# ── Step 5: Update config.js with Lambda URL ──────────────────────────────────
echo "5/5  Updating ../config.js and uploading to S3..."
CONFIG_FILE="../config.js"
cat > "$CONFIG_FILE" <<EOF
// Auto-generated by deploy.sh — do not edit manually
window.API_BASE = '$FUNC_URL';
EOF

# Upload config.js to S3
aws s3 cp "$CONFIG_FILE" "s3://${S3_BUCKET:-sajeedmoh-my-projects}/config.js" \
  --content-type "application/javascript" \
  --region "$REGION"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Deploy complete ==="
echo ""
echo "  Lambda URL : $FUNC_URL"
echo "  Login page : https://${S3_BUCKET:-sajeedmoh-my-projects}.s3-website.${REGION}.amazonaws.com/login.html"
echo ""
echo "  API endpoints:"
echo "    POST $FUNC_URL/api/auth/register"
echo "    POST $FUNC_URL/api/auth/login"
echo ""
rm -f "$ZIP_FILE"
