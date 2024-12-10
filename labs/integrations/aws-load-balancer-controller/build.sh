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

# Configuration
IAM_POLICY_NAME="AWS_Load_Balancer_Controller_Policy"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
VPC_ID=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text --region "$AWS_REGION")

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
print_info "VPC ID" "$VPC_ID"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"

echo -e "\n${YELLOW}======================================${NC}\n"

# Step 1: Add EKS Charts repo
echo -e "${YELLOW}Step 1: Adding EKS Charts repo...${NC}"
if ! helm repo list | grep -q 'eks-charts'; then
  if helm repo add eks https://aws.github.io/eks-charts; then
    echo -e "${GREEN}EKS Charts repo added successfully.\n${NC}"
  else
    echo -e "${RED}Failed to add EKS Charts repo.\n${NC}"
  fi
else
  echo -e "${GREEN}EKS Charts repo already exists.\n${NC}"
fi

# Step 2: Update EKS Charts repo
echo -e "${YELLOW}Step 2: Updating EKS Charts repo...${NC}"
if helm repo update eks; then
  echo -e "${GREEN}EKS Charts repo updated successfully.\n${NC}"
else
  echo -e "${RED}Failed to update EKS Charts repo.\n${NC}"
  exit 0
fi

# Function to get the latest chart version
get_chart_versions() {
  # Define color codes using ANSI escape sequences
  versions=$(helm search repo eks/aws-load-balancer-controller --versions --output json |
           jq -r '.[] | "\(.version),\(.app_version)"' |
           head -n 10)
  echo -e "${BLUE}Available versions for aws-load-balancer-controller:${NC}"
  echo -e "${GREEN}CHART VERSION   APP VERSION${NC}"

  while IFS=',' read -r chart_version app_version; do
      printf "%-15s %s\n" "$chart_version" "$app_version"
  done <<< "$versions"
}

get_latest_chart_version(){
  # Fetch the latest chart version
  version=$(helm search repo eks/aws-load-balancer-controller --versions --output json )
  CHART_VERSION=$(echo "$version"| jq -r '.[0].version')

  # If you also want the corresponding app version:
  APP_VERSION=$(echo "$version" | jq -r '.[0].app_version')
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
  echo -e "${GREEN}Using latest helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using latest helm app version: ${APP_VERSION}\n${NC}"
else
  CHART_VERSION="$1"
  APP_VERSION="$2"
  echo -e "${GREEN}Using specified helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using specified helm chart version: ${APP_VERSION}\n${NC}"
fi

# Step 3: Create IAM policy
echo -e "${YELLOW}Step 3: Creating IAM policy...${NC}"
if ! aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "$IAM_POLICY_NAME"; then
  if aws iam create-policy --policy-name "$IAM_POLICY_NAME" --policy-document file://policy.json; then
    echo -e "${GREEN}IAM policy created successfully.\n${NC}"
  else
    echo -e "${RED}Failed to create IAM policy.${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}IAM policy already exists.\n${NC}"

  IAM_POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='$IAM_POLICY_NAME'].Arn" \
    --output text)

  if aws iam create-policy-version  \
    --policy-arn "$IAM_POLICY_ARN" \
    --policy-document file://policy.json \
    --set-as-default \
    ; then
    echo -e "${GREEN}IAM policy is updated.\n${NC}"
  else
    echo -e "${RED}Failed to update IAM policy.${NC}"
    exit 0
  fi
fi

# Step 4: Create IAM service account
echo -e "${YELLOW}Step 4: Creating IAM service account...${NC}"
if eksctl create iamserviceaccount \
  --namespace kube-system \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --attach-policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
  --approve \
  --override-existing-serviceaccounts; then
  echo -e "${GREEN}IAM service account created successfully.\n${NC}"
else
  echo -e "${RED}Failed to create IAM service account.${NC}"
  exit 0
fi

# Step 5: Apply CRDs
echo -e "${YELLOW}Step 5: Applying CRDs...${NC}"
if kubectl apply -k "github.com/aws/eks-charts//stable/aws-load-balancer-controller/crds?ref=master"; then
  echo -e "${GREEN}CRDs applied successfully.\n${NC}"
else
  echo -e "${RED}Failed to apply CRDs.${NC}"
  exit 0
fi

check_controller_installation() {
    local expected_chart_version="$1"
    local expected_app_version="$2"

    echo -e "${YELLOW}Checking if aws-load-balancer-controller is installed...${NC}"

    if helm list -n kube-system | grep -q 'aws-load-balancer-controller'; then
        echo -e "${GREEN}aws-load-balancer-controller is installed.${NC}"

        # Get installed versions
        local installed_versions=$(helm list -n kube-system -f aws-load-balancer-controller -o json | jq -r '.[0] | "\(.chart),\(.app_version)"')
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
            # Step 7: Install or upgrade aws-load-balancer-controller
            echo -e "${YELLOW}Step 7: Installing/Upgrading aws-load-balancer-controller...${NC}"
            if helm upgrade \
              --namespace kube-system \
              --install aws-load-balancer-controller \
              --version "$CHART_VERSION" \
              eks/aws-load-balancer-controller \
              --set serviceAccount.create=false \
              --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
              --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller \
              --set image.tag="$APP_VERSION" \
              --set clusterName="$EKS_CLUSTER_NAME" \
              --set region="$AWS_REGION" \
              --set vpcId="$VPC_ID"; then
              echo -e "${GREEN}aws-load-balancer-controller installed/upgraded successfully.\n${NC}"
            else
              echo -e "${RED}Failed to install/upgrade aws-load-balancer-controller.${NC}"
              exit 0
    fi
        fi
    else
        echo -e "${YELLOW}aws-load-balancer-controller is not installed. Proceeding with installation...${NC}"
        # Step 7: Install or upgrade aws-load-balancer-controller
        echo -e "${YELLOW}Step 7: Installing/Upgrading aws-load-balancer-controller...${NC}"
        if helm upgrade \
          --namespace kube-system \
          --install aws-load-balancer-controller \
          --version "$CHART_VERSION" \
          eks/aws-load-balancer-controller \
          --set serviceAccount.create=false \
          --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
          --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller \
          --set image.tag="$APP_VERSION" \
          --set clusterName="$EKS_CLUSTER_NAME" \
          --set region="$AWS_REGION" \
          --set vpcId="$VPC_ID"; then
          echo -e "${GREEN}aws-load-balancer-controller installed/upgraded successfully.\n${NC}"
        else
          echo -e "${RED}Failed to install/upgrade aws-load-balancer-controller.${NC}"
          exit 0
        fi
    fi
}

# Step 6: Check if aws-load-balancer-controller is installed
echo -e "${YELLOW}Step 6: Checking aws-load-balancer-controller installation...${NC}"
check_controller_installation "$CHART_VERSION" "$APP_VERSION"

# Step 8: List aws-load-balancer-controller
echo -e "${YELLOW}Step 8: Listing aws-load-balancer-controller...${NC}"
if helm list --all-namespaces --filter aws-load-balancer-controller; then
  echo -e "${GREEN}aws-load-balancer-controller listed successfully.\n${NC}"
else
  echo -e "${RED}Failed to list aws-load-balancer-controller.${NC}"
  exit 0
fi
