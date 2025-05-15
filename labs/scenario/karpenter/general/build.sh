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
# TODO: change this usage print info
print_usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "${GREEN}./build.sh${NC}                     - Setup the karpenter resources"
    echo -e "${GREEN}./build.sh help${NC}                - Show usage"
    echo -e "\n"
}

# Check if no parameters are provided
if [ "$1" = "help" ]; then
    print_usage
    exit 0
fi

# Environment Variables
echo -e "${YELLOW}Extracting environment variables...${NC}"
CURRENT_CONTEXT=$(kubectl config current-context)
export EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
NAMESPACE="kube-system"

echo -e "${YELLOW}Getting cluster version...${NC}"
export CLUSTER_VERSION=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output "json" | jq -r '.cluster.version')
if [ "$CLUSTER_VERSION" = "" ]; then
  echo -e "${RED}Failed to get cluster version.${NC}"
  exit 1
fi

# To get AL2 alias
echo -e "${YELLOW}Getting AL2 alias...${NC}"
export ALIAS=$(aws ssm get-parameters-by-path --path "/aws/service/eks/optimized-ami/$CLUSTER_VERSION/amazon-linux-2/" --recursive | jq -cr '.Parameters[].Name' | grep -v "recommended" | awk -F '/' '{print $8}' | sed -r 's/.*(v[[:digit:]]+)$/\1/' | sort -r | uniq | head -n 1)

echo -e "\n${YELLOW}=== Current Environment Configuration ===${NC}\n"
print_info "EKS Cluster Name" "$EKS_CLUSTER_NAME"
print_info "Cluster Version" "$CLUSTER_VERSION"
print_info "AL2 Alias" "$ALIAS"
print_info "AWS Region" "$AWS_REGION"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
echo -e "\n${YELLOW}======================================${NC}\n"

echo -e "${YELLOW}Applying NodePool configuration...${NC}"
envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${ALIAS}' < nodepool.yaml | kubectl apply -f -

echo -e "${YELLOW}Applying NodeClass configuration...${NC}"
envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${ALIAS}' < nodeclass.yaml | kubectl apply -f -

echo -e "${GREEN}Configuration applied successfully!${NC}"
