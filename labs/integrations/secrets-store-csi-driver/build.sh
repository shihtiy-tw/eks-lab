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

echo -e "\n${YELLOW}======================================${NC}\n"

# Step 1: Add Secrets Store CSI Driver Charts repo
echo -e "${YELLOW}Step 1: Adding Secrets Store CSI Driver Charts repo...${NC}"
if ! helm repo list | grep -q 'secrets-store-csi-driver'; then
  if helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts ; then
    echo -e "${GREEN}Secrets Store CSI Driver Charts repo added successfully.\n${NC}"
  else
    echo -e "${RED}Failed to add Secrets Store CSI Driver Charts repo.\n${NC}"
  fi
else
  echo -e "${GREEN}Secrets Store CSI Driver Charts repo already exists.\n${NC}"
fi

# Step 2: Update Secrets Store CSI Driver Charts repo
echo -e "${YELLOW}Step 2: Updating Secrets Store CSI Driver Charts repo...${NC}"
if helm repo update secrets-store-csi-driver; then
  echo -e "${GREEN}Secrets Store CSI Driver Charts repo updated successfully.\n${NC}"
else
  echo -e "${RED}Failed to update Secrets Store CSI Driver Charts repo.\n${NC}"
  exit 0
fi

# Function to get the latest chart version
get_chart_versions() {
  # Define color codes using ANSI escape sequences
  versions=$(helm search repo secrets-store-csi-driver/secrets-store-csi-driver --versions --output json |
           jq -r '.[] | "\(.version),\(.app_version)"' |
           head -n 10)
  echo -e "${BLUE}Available versions for secrets-store-csi-driver:${NC}"
  echo -e "${GREEN}CHART VERSION   APP VERSION${NC}"

  while IFS=',' read -r chart_version app_version; do
      printf "%-15s %s\n" "$chart_version" "$app_version"
  done <<< "$versions"
}

get_latest_chart_version(){
  # Fetch the latest chart version
 version=$(helm search repo secrets-store-csi-driver/secrets-store-csi-driver --versions --output json)
  CHART_VERSION=$(echo "$version" | jq -r '.[0].version')
  # If you also want the corresponding app version:
  APP_VERSION=$(echo "$version" | jq -r '.[0].app_version')
  echo -e "${GREEN}Using latest helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using latest helm app version: ${APP_VERSION}\n${NC}"
}


# If no parameter is provided, print all available versions and exit
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}Step 3: Listing all available helm chart versions for EKS ${CLUSTER_VERSION}:${NC}"
  CHART_VERSIONS=$(get_chart_versions)
  echo "$CHART_VERSIONS"
  exit 0
fi

# If parameter is 'latest', get the latest version
if [ "$1" = "latest" ]; then
  get_latest_chart_version
else
  CHART_VERSION="$1"
  APP_VERSION="$2"
  echo -e "${GREEN}Using specified helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using specified helm chart version: ${APP_VERSION}\n${NC}"
fi

echo -e "${YELLOW}Step 7: Installing/Upgrading secrets-store-csi-driver...${NC}"

if helm upgrade \
  -n kube-system \
  --install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  --version "$CHART_VERSION"; then
  echo -e "${GREEN}secrets-store-csi-driver installed/upgraded successfully.\n${NC}"
else
  echo -e "${RED}Failed to install/upgrade secrets-store-csi-driver.${NC}"
  exit 0
fi

# Step 8: List secrets-store-csi-driver
echo -e "${YELLOW}Step 8: Listing secrets-store-csi-driver...${NC}"
if helm list --all-namespaces --filter secrets-store; then
  echo -e "${GREEN}secrets-store-csi-driver listed successfully.\n${NC}"
else
  echo -e "${RED}Failed to list aws-load-balancer-controller.${NC}"
  exit 0
fi
