#!/usr/bin/env bash
# ./build.sh
# ./build.sh <chart version> <app version>
# ./build.sh 100.2410.0 24.10.0
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

# Configuration
# IAM_POLICY_NAME="AWS_Load_Balancer_Controller_Policy"
# SERVICE_ACCOUNT_NAME="trident-operator"
VPC_ID=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text --region "$AWS_REGION")
NAMESPACE="ingress-nginx"
APP_NAME="ingress-nginx"
APP_NAME_STRING="NGINX Ingress Controller"
CHART_NAME="ingress-nginx"
CHART_NAME_STRING="NGINX Ingress Controller"
CHART_URL="https://kubernetes.github.io/ingress-nginx"
REPO_NAME="ingress-nginx"
REPO_NAME_STRING="NGINX Ingress Controller"

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
# print_info "VPC ID" "$VPC_ID"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"

echo -e "\n${YELLOW}======================================${NC}\n"

# Step 1: Add EKS Charts repo
echo -e "${YELLOW}Step 1: Adding $REPO_NAME_STRING repo...${NC}"
if ! helm repo list | grep -q '$REPO_NAME'; then
  if helm repo add "$REPO_NAME" "$CHART_URL"; then
    echo -e "${GREEN}$REPO_NAME_STRING repo added successfully.${NC}"
  else
    echo -e "${RED}Failed to add NetApp Tridena charts repo.${NC}"
  fi
else
  echo -e "${GREEN}$REPO_NAME_STRING repo already exists.${NC}"
fi

# Step 2: Update $REPO_NAME_STRING repo
echo -e "${YELLOW}\nStep 2: Updating $REPO_NAME_STRING repo...${NC}"
if helm repo update "$REPO_NAME"; then
  echo -e "${GREEN}$REPO_NAME_STRING repo updated successfully.${NC}"
else
  echo -e "${RED}Failed to update $REPO_NAME_STRING repo.${NC}"
  exit 0
fi

# Function to get the latest chart version
get_chart_versions() {
  # Define color codes using ANSI escape sequences
  versions=$(helm search repo "$REPO_NAME/$CHART_NAME" --versions --output json |
           jq -r '.[] | "\(.version),\(.app_version)"' |
           head -n 10)
  echo -e "${BLUE}Available versions for $CHART_NAME_STRING:${NC}"
  echo -e "${GREEN}CHART VERSION   APP VERSION${NC}"

  while IFS=',' read -r chart_version app_version; do
      printf "%-15s %s\n" "$chart_version" "$app_version"
  done <<< "$versions"
}

get_latest_chart_version(){
  # Fetch the latest chart version
  version=$(helm search repo "$REPO_NAME/$CHART_NAME" --versions --output json )
  CHART_VERSION=$(echo "$version"| jq -r '.[0].version')

  # If you also want the corresponding app version:
  APP_VERSION=$(echo "$version" | jq -r '.[0].app_version')
}


# If no parameter is provided, print all available versions and exit
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}\nStep 3: Listing all available helm chart versions for $CHART_NAME_STRING ${CLUSTER_VERSION}:${NC}"
  CHART_VERSIONS=$(get_chart_versions)
  echo "$CHART_VERSIONS"
  exit 0
fi

# If parameter is 'latest', get the latest version
if [ "$1" = "latest" ]; then
  get_latest_chart_version
  echo -e "${GREEN}Using latest helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using latest helm app version: ${APP_VERSION}\n${NC}"
else
  CHART_VERSION="$1"
  APP_VERSION="$2"
  echo -e "${GREEN}Using specified helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using specified helm chart version: ${APP_VERSION}\n${NC}"
fi

helm_command() {
  helm upgrade \
    --install "$APP_NAME" \
    --version "$CHART_VERSION" \
    "$REPO_NAME/$CHART_NAME" \
    --create-namespace \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --wait
}

check_controller_installation() {
    local expected_chart_version="$1"
    local expected_app_version="$2"

    echo -e "${YELLOW}Checking if $CHART_NAME_STRING is installed...${NC}"

    if helm list -n "$NAMESPACE" | grep -q '$CHART_NAME'; then
        echo -e "${GREEN}$CHART_NAME_STRING is installed.${NC}"

        # Get installed versions
        local installed_versions=$(helm list -n "$NAMESPACE" -f "$CHART_NAME" -o json | jq -r '.[0] | "\(.chart),\(.app_version)"')
        local installed_chart_version=$(echo "$installed_versions" | cut -d',' -f1 | awk -F- '{print $NF}')
        local installed_app_version=$(echo "$installed_versions" | cut -d',' -f2)

        echo -e "Installed Chart Version: ${BLUE}$installed_chart_version${NC}"
        echo -e "Installed App Version: ${BLUE}$installed_app_version${NC}"

        if [ "$installed_chart_version" = "$expected_chart_version" ] && [ "$installed_app_version" = "$expected_app_version" ]; then
            echo -e "${GREEN}Installed versions match the expected versions... Skip the installation/upgrade\n${NC}"
        else
            echo -e "${RED}Installed versions do not match the expected versions.${NC}"
            echo -e "Expected Chart Version: ${BLUE}$expected_chart_version${NC}"
            echo -e "Expected App Version: ${BLUE}$expected_app_version${NC}\n"
            # Step 7: Install or upgrade $CHART_NAME_STRING
            echo -e "${YELLOW}\nStep 7: Installing/Upgrading $CHART_NAME_STRING...${NC}"
            # select node with label: gpu-node: true
            if helm_command; then
              echo -e "${GREEN}$CHART_NAME_STRING installed/upgraded successfully.\n${NC}"
            else
              echo -e "${RED}Failed to install/upgrade $CHART_NAME_STRING.${NC}"
              exit 0
    fi
        fi
    else
        echo -e "${YELLOW}$CHART_NAME_STRING is not installed. Proceeding with installation...${NC}"
        # Step 7: Install or upgrade $CHART_NAME_STRING
        echo -e "${YELLOW}\nStep 7: Installing/Upgrading $CHART_NAME_STRING...${NC}"
        # select node with label: gpu-node: true
        if helm_command; then
          echo -e "${GREEN}$CHART_NAME_STRING installed/upgraded successfully.\n${NC}"
        else
          echo -e "${RED}Failed to install/upgrade $CHART_NAME_STRING.${NC}"
          exit 0
        fi
    fi
}

# Step 6: Check if $CHART_NAME_STRING is installed
echo -e "${YELLOW}\nStep 6: Checking $CHART_NAME_STRING installation...${NC}"
check_controller_installation "$CHART_VERSION" "$APP_VERSION"

# Step 8: List $CHART_NAME_STRING
echo -e "${YELLOW}\nStep 8: Listing $APP_NAME_STRING...${NC}"
if helm list --all-namespaces --filter "$APP_NAME"; then
  echo -e "${GREEN}$APP_NAME_STRING listed successfully.\n${NC}"
else
  echo -e "${RED}Failed to list $APP_NAME_STRING.${NC}"
  exit 0
fi
