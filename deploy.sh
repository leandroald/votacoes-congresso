#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-sa-east-1}"
TARGET_REGION="${TARGET_REGION:-sa-east-1}"

echo "▶️ Região ativa do CLI: $(aws configure get region || echo 'desconhecida')"
echo "▶️ Região alvo do deploy: ${TARGET_REGION}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
echo "▶️ Conta AWS: ${ACCOUNT}"

BUCKET="votacoes-congresso-site-${ACCOUNT}"
echo "▶️ Bucket: ${BUCKET}"

# 1) Build
echo "🧱 Buildando frontend..."
if [ -f package-lock.json ]; then
  npm ci >/dev/null 2>&1 || npm ci
else
  npm install
fi
npm run build

# 2) S3 – criar/ajustar bucket de website
echo "🪣 Conferindo bucket s3://${BUCKET}..."
if ! aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "🪣 Criando bucket em ${TARGET_REGION}..."
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${TARGET_REGION}" \
    --create-bucket-configuration LocationConstraint="${TARGET_REGION}" >/dev/null
else
  echo "♻️ Bucket já existe, seguindo..."
fi

echo "🔓 Desativando Public Access Block do bucket..."
aws s3control put-public-access-block \
  --account-id "${ACCOUNT}" \
  --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false >/dev/null

echo "🌐 Habilitando website hosting no S3..."
aws s3api put-bucket-website --bucket "${BUCKET}" --website-configuration '{
  "IndexDocument": { "Suffix": "index.html" },
  "ErrorDocument": { "Key": "index.html" }
}' >/dev/null

echo "📝 Aplicando bucket policy pública (somente leitura aos objetos)..."
aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"PublicReadGetObject\",
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::${BUCKET}/*\"
  }]
}" >/dev/null

# 3) Publicar artefatos
echo "🚚 Publicando arquivos para s3://${BUCKET}..."
# limpeza rápida de sobras antigas (opcional, mas útil)
aws s3 sync dist/ "s3://${BUCKET}/" \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html"

# index com cache curtinho (SPA)
aws s3 cp dist/index.html "s3://${BUCKET}/index.html" \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "text/html"

SITE_URL="http://${BUCKET}.s3-website-${TARGET_REGION}.amazonaws.com"
echo "✅ Site (HTTP) via S3:  ${SITE_URL}"

# 4) CloudFront
echo "🧭 Procurando distribuição CloudFront existente para essa origem..."
WEBSITE_DOMAIN="${BUCKET}.s3-website-${TARGET_REGION}.amazonaws.com"
DIST_ID="$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName=='${WEBSITE_DOMAIN}']].Id | [0]" --output text 2>/dev/null || true)"

if [ "${DIST_ID}" = "None" ] || [ -z "${DIST_ID}" ]; then
  echo "🆕 Criando distribuição CloudFront..."
  CREATE_OUT="$(aws cloudfront create-distribution --distribution-config "{
    \"CallerReference\": \"deploy-$(date +%s)\",
    \"Comment\": \"votacoes-congresso site\",
    \"Enabled\": true,
    \"Origins\": {
      \"Quantity\": 1,
      \"Items\": [{
        \"Id\": \"s3-website-origin\",
        \"DomainName\": \"${WEBSITE_DOMAIN}\",
        \"CustomOriginConfig\": {
          \"HTTPPort\": 80,
          \"HTTPSPort\": 443,
          \"OriginProtocolPolicy\": \"http-only\"
        }
      }]
    },
    \"DefaultCacheBehavior\": {
      \"TargetOriginId\": \"s3-website-origin\",
      \"ViewerProtocolPolicy\": \"redirect-to-https\",
      \"AllowedMethods\": {\"Quantity\": 2, \"Items\": [\"GET\",\"HEAD\"]},
      \"Compress\": true,
      \"ForwardedValues\": {
        \"QueryString\": true,
        \"Cookies\": {\"Forward\": \"none\"}
      },
      \"MinTTL\": 0,
      \"DefaultTTL\": 86400,
      \"MaxTTL\": 31536000
    },
    \"CustomErrorResponses\": {
      \"Quantity\": 2,
      \"Items\": [
        {\"ErrorCode\": 404, \"ResponseCode\": \"200\", \"ResponsePagePath\": \"/index.html\"},
        {\"ErrorCode\": 403, \"ResponseCode\": \"200\", \"ResponsePagePath\": \"/index.html\"}
      ]
    },
    \"ViewerCertificate\": {\"CloudFrontDefaultCertificate\": true},
    \"DefaultRootObject\": \"index.html\"
  }")"
  DIST_ID="$(echo "${CREATE_OUT}" | jq -r '.Distribution.Id')"
  CF_DOMAIN="$(echo "${CREATE_OUT}" | jq -r '.Distribution.DomainName')"
else
  echo "♻️ Distribuição existente: ${DIST_ID}"
  CF_DOMAIN="$(aws cloudfront get-distribution --id "${DIST_ID}" --query 'Distribution.DomainName' --output text)"
  echo "🧹 Invalidando cache /* ..."
  aws cloudfront create-invalidation --distribution-id "${DIST_ID}" --paths "/*" >/dev/null
fi

echo "🌐 CloudFront: https://${CF_DOMAIN}"
echo "🎉 Pronto!"
