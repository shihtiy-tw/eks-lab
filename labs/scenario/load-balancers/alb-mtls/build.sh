#!/bin/bash
# $ ./build.sh
# $ kustomize build . | kubectl delete -f -
#
# https://aws.amazon.com/blogs/containers/enabling-mtls-with-alb-in-amazon-eks/

# Colors for pretty output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')

# Create CA

openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 356 -nodes -subj '/CN=My BuildOn AWS Cert Authority'

cat << EOF > custom_openssl.cnf
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOF

openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj '/CN=My BuildOn AWS mTLS Client'
openssl x509 -req -sha256 -days 365 -in client.csr -CA ca.crt -CAkey ca.key -out client.crt -CAcreateserial -CAserial serial -extfile custom_openssl.cnf

# Create a trust store
TRUSTORE_BUCKET_NAME="${EKS_CLUSTER_NAME,,}-trust-store"

aws s3api create-bucket \
    --bucket "$TRUSTORE_BUCKET_NAME" \
    --region "$AWS_REGION"

aws s3api put-bucket-versioning --bucket "$TRUSTORE_BUCKET_NAME" --versioning-configuration Status=Enabled --region "$AWS_REGION"

aws s3 cp ca.crt s3://"$TRUSTORE_BUCKET_NAME"/trust-store/  --region us-east-2

# Create a connection logs bucket
LOG_BUCKET_NAME="${EKS_CLUSTER_NAME,,}-connection-log"

# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
declare -A REGIONS=(
["us-east-1"]="127311923021"
["us-east-2"]="033677994240"
["us-west-1"]="027434742980"
["us-west-2"]="797873946194"
["af-south-1"]="098369216593"
["ap-east-1"]="754344448648"
["ap-southeast-3"]="589379963580"
["ap-south-1"]="718504428378"
["ap-northeast-3"]="383597477331"
["ap-northeast-2"]="600734575887"
["ap-southeast-1"]="114774131450"
["ap-southeast-2"]="783225319266"
["ap-northeast-1"]="582318560864"
["ca-central-1"]="985666609251"
["eu-central-1"]="054676820928"
["eu-west-1"]="156460612806"
["eu-west-2"]="652711504416"
["eu-south-1"]="635631232127"
["eu-west-3"]="009996457667"
["eu-north-1"]="897822967062"
["me-south-1"]="076674570225"
["sa-east-1"]="507241528517"
)

ELB_ACCOUNT_ID="${REGIONS[$AWS_REGION]}"

aws s3api create-bucket \
    --bucket "$LOG_BUCKET_NAME" \
    --region "$AWS_REGION"

cat << EOF > elb-bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ELB_ACCOUNT_ID:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$LOG_BUCKET_NAME/mtls-alb/AWSLogs/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy --bucket "$LOG_BUCKET_NAME" --policy file://elb-bucket-policy.json

rm elb-bucket-policy.json

# Check if the trust store already exists
#
#
#
if ! aws elbv2 describe-trust-stores --query "TrustStores[].Name" --output text --region "$AWS_REGION"| grep "$EKS_CLUSTER_NAME"; then
  echo -e "${YELLOW}Trust store does not exist. Creating new trust store...${NC}"

  # Create a new trust store
  if TRUSTORE_ARN=$(aws elbv2 create-trust-store --name "$TRUSTSTORE_NAME" \
    --ca-certificates-bundle-s3-bucket "$TRUSTORE_BUCKET_NAME" \
    --ca-certificates-bundle-s3-key trust-store/ca.crt --region "$AWS_REGION" \
    --query 'TrustStore.TrustStoreArn' --output text); then
    echo -e "${GREEN}Trust store created successfully.${NC}"
  else
    echo -e "${RED}Failed to create trust store.${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}Trust store already exists.${NC}"

  # Get the existing ARN
  TRUSTORE_ARN=$(aws elbv2 describe-trust-stores --region "$AWS_REGION" \
    --query "TrustStores[?contains(Name, '$EKS_CLUSTER_NAME')].TrustStoreArn |[0]" --output text)

  # Update the existing trust store
  if aws elbv2 modify-trust-store --trust-store-arn "$TRUSTORE_ARN" \
    --ca-certificates-bundle-s3-bucket "$TRUSTORE_BUCKET_NAME" \
    --ca-certificates-bundle-s3-key trust-store/ca.crt --region "$AWS_REGION"; then
    echo -e "${GREEN}Trust store updated successfully.${NC}"
  else
    echo -e "${RED}Failed to update trust store.${NC}"
    exit 0
  fi
fi

# Export for use in other scripts
export TRUSTORE_ARN

echo -e "${GREEN}Trust store ARN: ${TRUSTORE_ARN}${NC}"


# ACM certificate for ALB
export CERTIFICATE_ARN=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?contains(DomainName, 'aws')].CertificateArn | [0]" \
  --output text)


# External DNS
ZONES_DATA=$(aws route53 list-hosted-zones --no-paginate --output json | jq -r '.HostedZones[] | select(.Name | contains("aws")) | select(.Config.PrivateZone==false) | .Id + " " + .Name' | head -1)

read -r ZONE_ID ZONE_NAME_DOT <<< "$ZONES_DATA"

echo "Zone ID: $ZONE_ID"
echo "Zone Name: $ZONE_NAME_DOT"

ZONE_NAME=$(echo "$ZONE_NAME_DOT" | sed 's/\.$//')
export SERVICES_DOMAIN="mtls."$ZONE_NAME

echo "$CERTIFICATE_ARN, $TRUSTORE_ARN, $SERVICES_DOMAIN"

kustomize build . \
  | sed -e "s|SERVICES_DOMAIN|$SERVICES_DOMAIN|g" \
  -e "s|CERTIFICATE_ARN|$CERTIFICATE_ARN|g" \
  -e "s|ZONE_NAME|$ZONE_NAME|g" \
  -e "s|ZONE_ID|$ZONE_ID|g" \
  -e "s|TRUSTORE_ARN|$TRUSTORE_ARN|g" \
  -e "s|LOG_BUCKET_NAME|$LOG_BUCKET_NAME|g" \
  | kubectl apply -f -


echo "Try $ curl https://$SERVICES_DOMAIN --cacert ca.crt --key client.key --cert client.crt -v"

