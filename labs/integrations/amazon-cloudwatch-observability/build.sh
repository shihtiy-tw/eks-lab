#!/usr/bin/env bash
# Usage:
#   ./build.sh                     - List all available addon versions
#   ./build.sh latest              - Install/update to the latest addon version
#   ./build.sh <specific_version>  - Install/update to a specific addon version
# Example: ./build.sh v1.35.0-eksbuild.1

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

# Configuration
SERVICE_ACCOUNT_NAME="cloudwatch-agent"
ADDON_NAME="amazon-cloudwatch-observability"
IAM_POLICY="arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
NAMESPACE="amazon-cloudwatch"

# Get cluster version
CLUSTER_VERSION=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output "json" | jq -r '.cluster.version')
if [ "$CLUSTER_VERSION" = "" ]; then
  echo -e "${RED}Failed to get cluster version.${NC}"
  exit 1
fi

# Pretty print function
print_info() {
    printf "${BLUE}%-30s${NC} : ${GREEN}%s${NC}\n" "$1" "$2"
}

# Display environment information
echo -e "\n${YELLOW}=== Current Environment Configuration ===${NC}\n"

print_info "EKS Cluster Name" "$EKS_CLUSTER_NAME"
print_info "EKS Cluster Version" "$CLUSTER_VERSION"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"
print_info "Addon Name" "$ADDON_NAME"

echo -e "\n${YELLOW}======================================${NC}\n"

# Function to get the latest addon version
get_latest_addon_version() {
  aws eks describe-addon-versions \
    --addon-name "$ADDON_NAME" \
    --kubernetes-version "$CLUSTER_VERSION" \
    --query 'addons[].addonVersions[].addonVersion' \
    --output text | tr '\t' '\n' | sort -V | tail -n 1
}

# If no parameter is provided, print all available versions and exit
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}Listing all available addon versions for EKS ${CLUSTER_VERSION}:${NC}"
  aws eks describe-addon-versions \
    --addon-name "$ADDON_NAME" \
    --kubernetes-version "$CLUSTER_VERSION" \
    --query 'addons[].addonVersions[].addonVersion' \
    --output table
  echo -e "\n${YELLOW}Usage:${NC}"
  echo -e "  ${GREEN}./build.sh${NC}                     - List all available addon versions"
  echo -e "  ${GREEN}./build.sh latest${NC}              - Install/update to the latest addon version"
  echo -e "  ${GREEN}./build.sh <specific_version>${NC}  - Install/update to a specific addon version"
  echo -e "Example: ${GREEN}./build.sh v1.35.0-eksbuild.1${NC}"
  exit 0
fi

# If parameter is 'latest', get the latest version
if [ "$1" = "latest" ]; then
  ADDON_VERSION=$(get_latest_addon_version)
  echo -e "${GREEN}Using latest addon version: ${ADDON_VERSION}${NC}"
else
  ADDON_VERSION="$1"
  echo -e "${GREEN}Using specified addon version: ${ADDON_VERSION}${NC}"
fi

# Step 1: Create IAM Roles for Service Accounts
echo -e "${YELLOW}Step 1: Creating IAM Roles for Service Accounts...${NC}"
if eksctl create iamserviceaccount \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --attach-policy-arn "$IAM_POLICY" \
  --approve \
  --override-existing-serviceaccounts; then
  echo -e "${GREEN}IAM Roles for Service Accounts created successfully.${NC}"
else
  echo -e "${RED}Failed to create IAM Roles for Service Accounts.${NC}"
  exit 1
fi

# Step 2: Detect created IAM Role ARN
echo -e "${YELLOW}Step 2: Detecting created IAM Role ARN...${NC}"
IRSA_ROLE_NAME=$(eksctl get iamserviceaccount --cluster "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output "json" | jq -r '.[] | select(.metadata.namespace == "'"$NAMESPACE"'" and .metadata.name == "'"$SERVICE_ACCOUNT_NAME"'") | .status.roleARN')
if [ "$IRSA_ROLE_NAME" != "" ]; then
  echo -e "${GREEN}IAM Role ARN detected: ${IRSA_ROLE_NAME}${NC}"
else
  echo -e "${RED}Failed to detect IAM Role ARN.${NC}"
  exit 1
fi

# Step 3: Create or update existing addon
echo -e "${YELLOW}Step 3: Creating or updating existing addon...${NC}"
if aws eks list-addons --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output "text" | grep -q "$ADDON_NAME"; then
  EXISTED_ADDON_VERSION=$(aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --addon-name "$ADDON_NAME" --region "$AWS_REGION" --output "json" | jq -r '.addon.addonVersion')
  echo -e "${BLUE}Existing addon version: ${EXISTED_ADDON_VERSION}${NC}"

  if aws eks update-addon \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --addon-name "$ADDON_NAME" \
    --addon-version "$ADDON_VERSION" \
    --service-account-role-arn "$IRSA_ROLE_NAME" \
    --resolve-conflicts "OVERWRITE"; then
    echo -e "${GREEN}Addon updated successfully.${NC}"
  else
    echo -e "${RED}Failed to update addon.${NC}"
    exit 1
  fi
else
  if aws eks create-addon \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --addon-name "$ADDON_NAME" \
    --addon-version "$ADDON_VERSION" \
    --service-account-role-arn "$IRSA_ROLE_NAME" \
    --resolve-conflicts "OVERWRITE"; then
    echo -e "${GREEN}Addon created successfully.${NC}"
  else
    echo -e "${RED}Failed to create addon.${NC}"
    exit 1
  fi
fi

echo -e "\n${YELLOW}======================================${NC}"
echo -e "${GREEN}Script execution completed successfully.${NC}"
