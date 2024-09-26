#!/usr/bin/env bash
# ./build.sh
# ./build.sh <image version> <chart version>
# ./build.sh v2.8.3 1.8.3

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
IMAGE_TAG_VERSION=${1:-"v2.8.3"}
CHART_VERSION=${2:-"1.8.3"}
VPC_ID=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text --region "$AWS_REGION")


# Pretty print function
print_info() {
    printf "${BLUE}%-30s${NC} : ${GREEN}%s${NC}\n" "$1" "$2"
}

# Display environment information
echo -e "\n${YELLOW}=== Current Environment Configuration ===${NC}\n"

print_info "EKS Cluster Name" "$EKS_CLUSTER_NAME"
print_info "VPC ID" "$VPC_ID"
print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"
print_info "App Version" "$IMAGE_TAG_VERSION"
print_info "Chart Version" "$CHART_VERSION"

echo -e "\n${YELLOW}======================================${NC}\n"

# Step 1: Add EKS Charts repo
echo -e "${YELLOW}Step 1: Adding EKS Charts repo...${NC}"
if ! helm repo list | grep -q 'eks-charts'; then
  if helm repo add eks https://aws.github.io/eks-charts; then
    echo -e "${GREEN}EKS Charts repo added successfully.${NC}"
  else
    echo -e "${RED}Failed to add EKS Charts repo.${NC}"
  fi
else
  echo -e "${GREEN}EKS Charts repo already exists.${NC}"
fi

# Step 2: Update EKS Charts repo
echo -e "${YELLOW}Step 2: Updating EKS Charts repo...${NC}"
if helm repo update eks; then
  echo -e "${GREEN}EKS Charts repo updated successfully.${NC}"
else
  echo -e "${RED}Failed to update EKS Charts repo.${NC}"
  exit 0
fi

# Step 3: Create IAM policy
echo -e "${YELLOW}Step 3: Creating IAM policy...${NC}"
if ! aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "$IAM_POLICY_NAME"; then
  if aws iam create-policy --policy-name "$IAM_POLICY_NAME" --policy-document file://policy.json; then
    echo -e "${GREEN}IAM policy created successfully.${NC}"
  else
    echo -e "${RED}Failed to create IAM policy.${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}IAM policy already exists.${NC}"
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
  echo -e "${GREEN}IAM service account created successfully.${NC}"
else
  echo -e "${RED}Failed to create IAM service account.${NC}"
  exit 0
fi

# Step 5: Apply CRDs
echo -e "${YELLOW}Step 5: Applying CRDs...${NC}"
if kubectl apply -k "github.com/aws/eks-charts//stable/aws-load-balancer-controller/crds?ref=master"; then
  echo -e "${GREEN}CRDs applied successfully.${NC}"
else
  echo -e "${RED}Failed to apply CRDs.${NC}"
  exit 0
fi

# Step 6: Check if aws-load-balancer-controller is installed
echo -e "${YELLOW}Step 6: Checking if aws-load-balancer-controller is installed...${NC}"
if helm list --all-namespaces | grep -q 'aws-load-balancer-controller'; then
  echo -e "${GREEN}aws-load-balancer-controller is already installed.${NC}"
else
  echo -e "${YELLOW}aws-load-balancer-controller is not installed. Installing...${NC}"
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
    --set image.tag="$IMAGE_TAG_VERSION" \
    --set clusterName="$EKS_CLUSTER_NAME" \
    --set region="$AWS_REGION" \
    --set vpcId="$VPC_ID"; then
    echo -e "${GREEN}aws-load-balancer-controller installed/upgraded successfully.${NC}"
  else
    echo -e "${RED}Failed to install/upgrade aws-load-balancer-controller.${NC}"
    exit 0
  fi
fi

# Step 8: List aws-load-balancer-controller
echo -e "${YELLOW}Step 8: Listing aws-load-balancer-controller...${NC}"
if helm list --all-namespaces --filter aws-load-balancer-controller; then
  echo -e "${GREEN}aws-load-balancer-controller listed successfully.${NC}"
else
  echo -e "${RED}Failed to list aws-load-balancer-controller.${NC}"
  exit 0
fi
