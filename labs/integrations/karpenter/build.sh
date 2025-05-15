#!/usr/bin/env bash

# Colors for pretty output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored and formatted output
print_info() {
    printf "${BLUE}%-30s${NC} : ${GREEN}%s${NC}\n" "$1" "$2"
}

# Function to print script usage information
print_usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "${GREEN}./build.sh${NC}                                - List all available chart versions"
    echo -e "${GREEN}./build.sh latest${NC}                         - Install/update to the latest chart version"
    echo -e "${GREEN}./build.sh <chart version> <app version>${NC}  - Install/update to a specific chart version"
    echo -e "${YELLOW}Example:${NC}"
    echo -e "${GREEN}./build.sh 1.0.7 1.0.7${NC}"
    echo -e "\n"
}

# Check if no parameters are provided
if [ $# -eq 0 ]; then
    print_usage
    exit 0
fi

# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
NAMESPACE="kube-system"

# Configuration
SERVICE_ACCOUNT_NAME="karpenter"
IAM_ROLE_NAME="${EKS_CLUSTER_NAME}-karpenter"
IAM_POLICY_NAME="KarpenterControllerPolicy-${EKS_CLUSTER_NAME}" # defined by CloudFormation stack

# Get cluster version
CLUSTER_VERSION=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output "json" | jq -r '.cluster.version')
if [ "$CLUSTER_VERSION" = "" ]; then
  echo -e "${RED}Failed to get cluster version.${NC}"
  exit 1
fi

# Display environment information
echo -e "\n${YELLOW}=== Current Environment Configuration ===${NC}\n"

print_info "EKS Cluster Name" "$EKS_CLUSTER_NAME"
print_info "EKS Cluster Version" "$CLUSTER_VERSION"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "IAM Role Name" "$IAM_ROLE_NAME"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"

echo -e "\n${YELLOW}======================================${NC}\n"

# ... (rest of the script remains unchanged)

# Version selection logic
if [ "$1" = "latest" ]; then
  # Get the chart information
  CHART_INFO=$(helm show chart oci://public.ecr.aws/karpenter/karpenter)

  # Extract appVersion and version
  APP_VERSION=$(echo "$CHART_INFO" | grep '^appVersion:' | awk '{print $2}')
  CHART_VERSION=$(echo "$CHART_INFO" | grep '^version:' | awk '{print $2}')
  echo -e "${GREEN}Using latest helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using latest helm app version: ${APP_VERSION}\n${NC}"
else
  CHART_VERSION="$1"
  APP_VERSION="$2"
  echo -e "${GREEN}Using specified helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using specified helm app version: ${APP_VERSION}\n${NC}"
fi

# Setup IAM resources
echo -e "${YELLOW}Setting up IAM resources...${NC}"
curl -fsSL "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${APP_VERSION}/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml" -O

if [ ! -f "cloudformation.yaml" ]; then
  echo -e "${RED}Failed to download cloudformation.yaml${NC}"
  exit 1
fi

# Deploy CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
  --stack-name "Karpenter-${EKS_CLUSTER_NAME}" \
  --template-file cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${EKS_CLUSTER_NAME}"

rm -vf cloudformation.yaml # cleanup

# Create IAM identity mapping
echo -e "${YELLOW}Creating IAM identity mapping...${NC}"
eksctl create iamidentitymapping \
  --username "system:node:{{EC2PrivateDNSName}}" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${EKS_CLUSTER_NAME}" \
  --group "system:bootstrappers" \
  --group "system:nodes"

# Create IAM Roles for Service Accounts
echo -e "${YELLOW}Creating IAM Roles for Service Accounts...${NC}"
eksctl create iamserviceaccount \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --role-name "$IAM_ROLE_NAME" \
  --attach-policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
  --approve \
  --override-existing-serviceaccounts

# Install Karpenter CRDs
echo -e "${YELLOW}Installing Karpenter Custom Resource Definitions...${NC}"
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd --version "$CHART_VERSION" --namespace "$NAMESPACE" --create-namespace

# Check if Helm resources exist
echo -e "${YELLOW}Checking for existing Helm resources...${NC}"
helm list --all-namespaces | grep -q "$NAMESPACE"

# Ensure Helm registry is logged out
echo -e "${YELLOW}Ensuring Helm registry is logged out...${NC}"
helm registry logout public.ecr.aws

# Install Karpenter
echo -e "${YELLOW}Installing Karpenter...${NC}"
helm upgrade \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --install karpenter \
  --version "$CHART_VERSION" \
  oci://public.ecr.aws/karpenter/karpenter \
    --set serviceAccount.create=false \
    --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}" \
    --set settings.clusterName="$EKS_CLUSTER_NAME" \
    --set settings.interruptionQueue="$EKS_CLUSTER_NAME" \
    --set settings.clusterEndpoint="$CLUSTER_ENDPOINT" \
    --set controller.resources.requests.cpu=500m \
    --set controller.resources.requests.memory=500Mi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --set controller.logLevel=debug \
    --wait

# List installed Helm charts
echo -e "${YELLOW}Listing installed Helm charts...${NC}"
helm list --all-namespaces --filter karpenter

