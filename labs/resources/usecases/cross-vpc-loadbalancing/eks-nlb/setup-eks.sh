#!/bin/bash

# Exit on error
set -e

# Source the VPC configuration
source ../vpc-peering/vpc-config.env

echo "Setting up EKS cluster in VPC1 ($VPC1_ID)..."

# Create EKS cluster in VPC1
echo "Creating EKS cluster $CLUSTER_NAME..."

# Create cluster role
ROLE_NAME="eks-cluster-role"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

# Check if role exists
ROLE_EXISTS=$(aws iam get-role --role-name $ROLE_NAME 2>&1 || echo "not_exists")

if [[ $ROLE_EXISTS == *"not_exists"* ]]; then
  echo "Creating IAM role for EKS cluster..."
  
  # Create trust policy document
  cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # Create role
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json

  # Attach policy
  aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN
    
  # Clean up
  rm trust-policy.json
  
  # Wait for role to propagate
  echo "Waiting for IAM role to propagate..."
  sleep 10
fi

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query Role.Arn --output text)
echo "Using IAM role: $ROLE_ARN"

# Create EKS cluster
aws eks create-cluster \
  --name $CLUSTER_NAME \
  --role-arn $ROLE_ARN \
  --resources-vpc-config subnetIds=$SUBNET1_ID,$SUBNET2_ID,$SUBNET3_ID,securityGroupIds=$EKS_SG_ID,endpointPublicAccess=true,endpointPrivateAccess=true \
  --kubernetes-version 1.29

echo "Waiting for EKS cluster to be created (this may take 15-20 minutes)..."
aws eks wait cluster-active --name $CLUSTER_NAME

echo "EKS cluster $CLUSTER_NAME created successfully!"

# Create node group role
NODE_ROLE_NAME="eks-node-role"
NODE_POLICY_ARNS=(
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
)

# Check if node role exists
NODE_ROLE_EXISTS=$(aws iam get-role --role-name $NODE_ROLE_NAME 2>&1 || echo "not_exists")

if [[ $NODE_ROLE_EXISTS == *"not_exists"* ]]; then
  echo "Creating IAM role for EKS node group..."
  
  # Create trust policy document
  cat > node-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # Create role
  aws iam create-role \
    --role-name $NODE_ROLE_NAME \
    --assume-role-policy-document file://node-trust-policy.json

  # Attach policies
  for POLICY_ARN in "${NODE_POLICY_ARNS[@]}"; do
    aws iam attach-role-policy \
      --role-name $NODE_ROLE_NAME \
      --policy-arn $POLICY_ARN
  done
    
  # Clean up
  rm node-trust-policy.json
  
  # Wait for role to propagate
  echo "Waiting for IAM role to propagate..."
  sleep 10
fi

# Get node role ARN
NODE_ROLE_ARN=$(aws iam get-role --role-name $NODE_ROLE_NAME --query Role.Arn --output text)
echo "Using IAM role for nodes: $NODE_ROLE_ARN"

# Create node group
echo "Creating EKS node group..."
aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name ng-1 \
  --node-role $NODE_ROLE_ARN \
  --subnets $SUBNET1_ID $SUBNET2_ID $SUBNET3_ID \
  --instance-types t3.medium \
  --disk-size 20 \
  --scaling-config minSize=2,maxSize=4,desiredSize=2

echo "Waiting for EKS node group to be created (this may take 5-10 minutes)..."
aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name ng-1

echo "EKS node group created successfully!"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Save EKS configuration
echo "Saving EKS configuration..."
cat > eks-config.env << EOF
export CLUSTER_NAME=$CLUSTER_NAME
export CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.endpoint --output text)
export CLUSTER_CA=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.certificateAuthority.data --output text)
export CLUSTER_ROLE_ARN=$ROLE_ARN
export NODE_ROLE_ARN=$NODE_ROLE_ARN
EOF

echo "EKS setup complete!"
echo "Cluster endpoint: $(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.endpoint --output text)"
