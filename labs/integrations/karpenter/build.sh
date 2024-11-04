#!/usr/bin/env bash
# Usage:
# ./build.sh                     - List all available chart versions
# ./build.sh latest              - Install/update to the latest chart version
# ./build.sh <chart version> <app version>  Install/update to a specific chart version
# Example: ./build.sh 1.0.7 1.0.7
#

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
print_info "IAM Policy Name" "$IAM_POLICY_NAME"
print_info "IAM Role Name" "$IAM_ROLE_NAME"
print_info "Service Account Name" "$SERVICE_ACCOUNT_NAME"

echo -e "\n${YELLOW}======================================${NC}\n"

# Step 1: Add EKS Charts repo
#
# TODO: need to figure how to find the karpenter version
#
# $ helm repo add karpenter https://charts.karpenter.sh/
# "karpenter" has been added to your repositories
#
# $ helm search repo karpenter
# NAME                    CHART VERSION   APP VERSION     DESCRIPTION
# karpenter/karpenter     0.16.3          0.16.3          A Helm chart for Karpenter, an open-source node...
#
# echo -e "${YELLOW}Step 1: Adding EKS Charts repo...${NC}"
# if ! helm repo list | grep -q 'karpenter'; then
#   if helm repo add karpenter https://charts.karpenter.sh/; then
#     echo -e "${GREEN}Karpenter Charts repo added successfully.\n${NC}"
#   else
#     echo -e "${RED}Failed to add Karpenter Charts repo.\n${NC}"
#   fi
# else
#   echo -e "${GREEN}Karpenter Charts repo already exists.\n${NC}"
# fi
#
# # Step 2: Update EKS Charts repo
# echo -e "${YELLOW}Step 2: Updating Karpenter Charts repo...${NC}"
# if helm repo update karpenter; then
#   echo -e "${GREEN}Karpenter Charts repo updated successfully.\n${NC}"
# else
#   echo -e "${RED}Failed to update Karpenter Charts repo.\n${NC}"
#   exit 0
# fi

# Function to get the latest chart version
# get_chart_versions() {
#   # Define color codes using ANSI escape sequences
#   versions=$(helm search repo karpenter/karpenter --versions --output json |
#            jq -r '.[] | "\(.version),\(.app_version)"' |
#            head -n 10)
#   echo -e "${BLUE}Available versions for aws-load-balancer-controller:${NC}"
#   echo -e "${GREEN}CHART VERSION   APP VERSION${NC}"
#
#   while IFS=',' read -r chart_version app_version; do
#       printf "%-15s %s\n" "$chart_version" "$app_version"
#   done <<< "$versions"
# }
#
# get_latest_chart_version(){
#   # Fetch the latest chart version
#   version=$(helm search repo eks/aws-load-balancer-controller --versions --output json )
#   CHART_VERSION=$(echo "$version"| jq -r '.[0].version')
#
#   # If you also want the corresponding app version:
#   APP_VERSION=$(echo "$version" | jq -r '.[0].app_version')
# }


# If no parameter is provided, print all available versions and exit
# if [ $# -eq 0 ]; then
#   echo -e "${YELLOW}Step 3: Listing all available helm chart versions for EKS ${CLUSTER_VERSION}:${NC}"
#   CHART_VERSIONS=$(get_chart_versions)
#   echo "$CHART_VERSIONS"
#   exit 0
# fi

# If parameter is 'latest', get the latest version
if [ "$1" = "latest" ]; then
  # get_latest_chart_version
  # TODO: rmeove hardcode version
  APP_VERSION="1.0.7"
  CHART_VERSION="1.0.7"
  echo -e "${GREEN}Using latest helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using latest helm app version: ${APP_VERSION}\n${NC}"
else
  CHART_VERSION="$1"
  APP_VERSION="$2"
  echo -e "${GREEN}Using specified helm chart version: ${CHART_VERSION}${NC}"
  echo -e "${GREEN}Using specified helm chart version: ${APP_VERSION}\n${NC}"
fi

# setup IAM resource
curl -fsSL "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${APP_VERSION}/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml" -O

if [ ! -f "cloudformation.yaml" ]; then
  echo "Failed to download cloudformation.yaml"
  exit 1
fi

aws cloudformation deploy \
  --stack-name "Karpenter-${EKS_CLUSTER_NAME}" \
  --template-file cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${EKS_CLUSTER_NAME}"

rm -vf cloudformation.yaml # cleanup

echo "[debug] creating mapRole for aws-auth"
eksctl create iamidentitymapping \
  --username "system:node:{{EC2PrivateDNSName}}" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${EKS_CLUSTER_NAME}" \
  --group "system:bootstrappers" \
  --group "system:nodes"

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --name "$SERVICE_ACCOUNT_NAME" \
  --role-name "$IAM_ROLE_NAME" \
  --attach-policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd --version "$CHART_VERSION" --namespace "$NAMESPACE" --create-namespace

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q "$NAMESPACE"

# https://github.com/aws/karpenter/pull/3880
echo "[debug] ensure helm registry is logout"
helm registry logout public.ecr.aws

echo "[debug] setup karpenter/karpenter"

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
    --wait

echo "[debug] listing installed"
helm list --all-namespaces --filter karpenter

echo "[debug] post-install reminders"
echo "Before applying CRDs, you should check for karpenter discovery tags definitions."
