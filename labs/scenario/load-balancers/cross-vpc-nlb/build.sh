#!/bin/bash

# Exit on error
set -e

# Get Terraform outputs
echo "Loading configuration from Terraform outputs..."

# Change to the VPC peering directory and get outputs
cd ../../../resources/usecases/cross-vpc-loadbalancing/vpc-peering
VPC1_ID=$(terraform output -raw vpc1_id)
VPC2_ID=$(terraform output -raw vpc2_id)
EKS_SG_ID=$(terraform output -raw eks_security_group_id)
NLB_SG_ID=$(terraform output -raw nlb_security_group_id)
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

# Change to the EKS/NLB directory and get outputs
cd ../eks-nlb
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)
NLB_ARN=$(terraform output -raw nlb_arn)
NLB_DNS=$(terraform output -raw nlb_dns)
CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
CLUSTER_CA=$(terraform output -raw cluster_ca_certificate)

# Return to the original directory
cd ../../../../scenario/load-balancers/cross-vpc-nlb

echo "Configuration loaded:"
echo "VPC1_ID: $VPC1_ID"
echo "VPC2_ID: $VPC2_ID"
echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "TARGET_GROUP_ARN: $TARGET_GROUP_ARN"
echo "NLB_DNS: $NLB_DNS"


aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Create namespace
echo "Creating namespace..."
kubectl apply -f k8s-namespace.yaml

# Create IAM policy for AWS Load Balancer Controller
echo "Creating IAM policy for AWS Load Balancer Controller..."
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
POLICY_ARN=""

# Check if policy already exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ "$POLICY_ARN" = "" ]; then
  echo "Creating new IAM policy..."
  # Download policy document
  curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  # Create policy
  POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://iam-policy.json \
    --query 'Policy.Arn' \
    --output text)

  # Clean up
  rm iam-policy.json
else
  echo "Using existing IAM policy: $POLICY_ARN"
fi

eksctl utils associate-iam-oidc-provider --region="$REGION" --cluster="$CLUSTER_NAME" --approve

# Create IAM role for service account
echo "Creating IAM role for service account..."
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="$POLICY_ARN" \
  --override-existing-serviceaccounts \
  --region "$REGION" \
  --approve

# Get the role ARN
ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'aws-load-balancer-controller')].Arn" --output text)

# Install AWS Load Balancer Controller with custom VPC configuration
echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Replace placeholders in values file
sed -e "s|CLUSTER_NAME|$CLUSTER_NAME|g" \
    -e "s|REGION|$REGION|g" \
    -e "s|VPC2_ID|$VPC2_ID|g" \
    -e "s|ROLE_ARN|$ROLE_ARN|g" \
    k8s-aws-load-balancer-controller-values.yaml > values-temp.yaml

# Install controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f values-temp.yaml

# Clean up
rm values-temp.yaml

# Wait for controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=aws-load-balancer-controller \
  --timeout=90s

# Deploy sample application
echo "Deploying sample application..."
kubectl apply -f k8s-deployment-sample-app.yaml
kubectl apply -f k8s-service.yaml

# Wait for deployment to be ready
echo "Waiting for sample application to be ready..."
kubectl wait --namespace cross-vpc-demo \
  --for=condition=available deployment/sample-app \
  --timeout=90s

# Apply TargetGroupBinding
echo "Creating TargetGroupBinding..."
sed -e "s|TARGET_GROUP_ARN|$TARGET_GROUP_ARN|g" \
    -e "s|SECURITY_GROUP_ID|$NLB_SG_ID|g" \
    k8s-targetgroupbinding.yaml > tgb-temp.yaml

kubectl apply -f tgb-temp.yaml

# Clean up
rm tgb-temp.yaml

echo "Cross-VPC NLB setup complete!"
echo "NLB DNS Name: $NLB_DNS"
echo ""
echo "You can access the application at: http://$NLB_DNS"
echo ""
echo "To verify the TargetGroupBinding:"
echo "kubectl get targetgroupbinding -n cross-vpc-demo"
echo ""
echo "To check if targets are registered with the NLB:"
echo "aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN"
