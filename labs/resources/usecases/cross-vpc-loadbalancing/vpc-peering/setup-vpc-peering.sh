#!/bin/bash

# Exit on error
set -e

# Source the VPC configuration
source ./vpc-config.env

echo "Setting up VPC peering between VPC1 ($VPC1_ID) and VPC2 ($VPC2_ID)..."

# Create VPC peering connection
echo "Creating VPC peering connection..."
PEERING_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $VPC1_ID \
  --peer-vpc-id $VPC2_ID \
  --tag-specifications 'ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=eks-nlb-peering}]' \
  --query VpcPeeringConnection.VpcPeeringConnectionId \
  --output text)

# Accept the peering connection
echo "Accepting VPC peering connection..."
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID

# Update route tables for VPC1 to route traffic to VPC2
echo "Updating route table for VPC1 to route traffic to VPC2..."
aws ec2 create-route \
  --route-table-id $VPC1_RTB \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

# Update route tables for VPC2 to route traffic to VPC1
echo "Updating route table for VPC2 to route traffic to VPC1..."
aws ec2 create-route \
  --route-table-id $VPC2_RTB \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id $PEERING_ID

echo "VPC peering connection $PEERING_ID created and configured"
echo "PEERING_ID=$PEERING_ID" >> vpc-config.env

# Create security groups for cross-VPC communication
echo "Creating security groups for cross-VPC communication..."

# Create security group for EKS nodes in VPC1
EKS_SG_ID=$(aws ec2 create-security-group \
  --group-name eks-nodes-sg \
  --description "Security group for EKS nodes" \
  --vpc-id $VPC1_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=eks-nodes-sg}]' \
  --query GroupId \
  --output text)

# Create security group for NLB in VPC2
NLB_SG_ID=$(aws ec2 create-security-group \
  --group-name nlb-sg \
  --description "Security group for NLB" \
  --vpc-id $VPC2_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=nlb-sg}]' \
  --query GroupId \
  --output text)

# Allow inbound traffic from NLB security group to EKS security group
echo "Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
  --group-id $EKS_SG_ID \
  --protocol tcp \
  --port 80 \
  --source-group $NLB_SG_ID

# Allow outbound traffic from NLB security group to EKS security group
aws ec2 authorize-security-group-egress \
  --group-id $NLB_SG_ID \
  --protocol tcp \
  --port 80 \
  --destination-cidr-block 10.0.0.0/16

# Allow inbound traffic from anywhere to NLB security group
aws ec2 authorize-security-group-ingress \
  --group-id $NLB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

echo "Security groups created and configured:"
echo "EKS_SG_ID=$EKS_SG_ID"
echo "NLB_SG_ID=$NLB_SG_ID"

# Add security group IDs to config file
echo "export EKS_SG_ID=$EKS_SG_ID" >> vpc-config.env
echo "export NLB_SG_ID=$NLB_SG_ID" >> vpc-config.env

echo "VPC peering setup complete!"
