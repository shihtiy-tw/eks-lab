#!/usr/bin/env bash
# ./build.sh
# ./build.sh <chart version> <app version>
# ./build.sh 1.8.3 v2.8.3
# ./build.sh latest

CONTROLLER_IMAGE_TAG="v1.12.7"
SIDECAR_IMAGE_TAG="v1.27.2.0-prod"
INIT_IMAGE_TAG="v7-prod"

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
NAMESPACE="appmesh-system"

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

echo -e "\n${YELLOW}======================================${NC}\n"

# Configuration
SERVICE_ACCOUNT_NAME="appmesh-controller"
IAM_ROLE_NAME="AppMesh_Controller_Role"
IAM_POLICY_NAME="AppMesh_Controller_Policy"

print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "IAM Role Name" "$IAM_ROLE_NAME"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"

echo "[debug] detecting chart repo existance"

if helm repo list | grep -q 'eks-charts'; then
  echo "[debug] found chart repo"
else
  echo "[debug] setup chart repo"
  helm repo add eks https://aws.github.io/eks-charts || true
fi

echo "[debug] helm repo update"
helm repo update eks

echo "[debug] detecting IAM policy existance"
if aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "$IAM_POLICY_NAME" ; then
  echo "[debug] IAM policy existed"
else
  echo "[debug] IAM policy existance not found, creating"
  aws iam create-policy \
    --policy-name "$IAM_POLICY_NAME" \
    --policy-document file://policy.json
fi

echo "[debug] detecting namespace existance"

if kubectl get namespace | grep -q "$NAMESPACE"; then
  echo "[debug] found namespace"
else
  echo "[debug] creating namespace"
  kubectl create namespace "$NAMESPACE"
fi

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --attach-policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -k "github.com/aws/eks-charts//stable/appmesh-controller/crds?ref=master"

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'appmesh-controller'

# Function to get the latest chart version
get_chart_versions() {
  # Define color codes using ANSI escape sequences
  versions=$(helm search repo eks/appmesh-controller --versions --output json |
           jq -r '.[] | "\(.version),\(.app_version)"' |
           head -n 10)
  echo -e "${BLUE}Available versions for appmesh-controller:${NC}"
  echo -e "${GREEN}CHART VERSION   APP VERSION${NC}"

  while IFS=',' read -r chart_version app_version; do
      printf "%-15s %s\n" "$chart_version" "$app_version"
  done <<< "$versions"
}

get_latest_chart_version(){
  # Fetch the latest chart version
  version=$(helm search repo eks/appmesh-controller --versions --output json )
  CHART_VERSION=$(echo "$version"| jq -r '.[0].version')

  # If you also want the corresponding app version:
  APP_VERSION=$(echo "$version" | jq -r '.[0].app_version')
}

# If no parameter is provided, print all available versions and exit
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}Listing all available helm chart versions for EKS ${CLUSTER_VERSION}:${NC}"
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

# TODO: nice to have regional image setup
echo "[debug] setup eks/appmesh-controller"
helm upgrade \
  --namespace appmesh-system \
  --install appmesh-controller \
  --version "$CHART_VERSION" \
  eks/appmesh-controller \
    --set serviceAccount.create=false \
    --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
    --set region="$AWS_REGION"

echo "[debug] listing installed"
helm list --all-namespaces --filter appmesh-controller

