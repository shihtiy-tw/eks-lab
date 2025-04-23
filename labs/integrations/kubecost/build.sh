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

# Configuration
CHART_URL="oci://public.ecr.aws/kubecost/cost-analyzer"
NAMESPACE="kubecost"

# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
NAMESPACE="kube-system"

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

# Version selection logic
if [ "$1" = "latest" ]; then
  # Get the chart information
  CHART_INFO=$(helm show chart "$CHART_URL")

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

# Install kubecost
echo -e "${YELLOW}Installing Kubecost...${NC}"
helm upgrade \
  -i kubecost oci://public.ecr.aws/kubecost/cost-analyzer \
  --version "$CHART_VERSION"     \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml
# List installed Helm charts
echo -e "${YELLOW}Listing installed Helm charts...${NC}"
helm list --all-namespaces --filter kubecost


