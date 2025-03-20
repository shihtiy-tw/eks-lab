
#!/usr/bin/env bash
# ./build.sh
# ./build.sh <chart version> <app version>
# ./build.sh 1.8.3 v2.8.3
# ./build.sh latest

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
NAMESPACE=$(grep -E '^namespace:' kustomization.yaml | awk '{print $2}')

# Configuration
IAM_POLICY_NAME="IAMReadOnlyAccess"
SERVICE_ACCOUNT_NAME="awscli-sa"

# Pretty print function
print_info() {
    printf "${BLUE}%-30s${NC} : ${GREEN}%s${NC}\n" "$1" "$2"
}

IAM_POLICY_ARN=$(aws iam list-policies \
  --query "Policies[?PolicyName=='$IAM_POLICY_NAME'].Arn" \
  --output text)

echo -e "${YELLOW}Creating IAM service account...${NC}"
if eksctl create iamserviceaccount \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --attach-policy-arn "$IAM_POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts; then
  echo -e "${GREEN}IAM service account created successfully.\n${NC}"
else
  echo -e "${RED}Failed to create IAM service account.${NC}"
  exit 0
fi

# Display environment information
echo -e "\n${YELLOW}=== Current Environment Configuration ===${NC}\n"

print_info "EKS Cluster Name" "$EKS_CLUSTER_NAME"
print_info "EKS Cluster Version" "$CLUSTER_VERSION"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "Namespace" "$NAMESPACE"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"

echo -e "\n${YELLOW}======================================${NC}\n"
