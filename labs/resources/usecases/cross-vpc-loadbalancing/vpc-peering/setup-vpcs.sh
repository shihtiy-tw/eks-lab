#!/bin/bash

# Exit on error
set -e

# Get the AWS region or use default
aws configure set region "$1"
REGION=$(aws configure get region)
echo "Using AWS region: $REGION"

# Create two VPCs with non-overlapping CIDR blocks
echo "Creating VPCs..."
VPC1_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=eks-vpc}]' --query Vpc.VpcId --output text)
VPC2_ID=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=nlb-vpc}]' --query Vpc.VpcId --output text)

echo "Created VPC1 (EKS): $VPC1_ID"
echo "Created VPC2 (NLB): $VPC2_ID"

# Enable DNS hostnames for both VPCs
aws ec2 modify-vpc-attribute --vpc-id "$VPC1_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC2_ID" --enable-dns-hostnames

# Get availability zones
echo "Getting availability zones..."
AZS=("$(aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[0:3].ZoneName' --output text)")
echo "Using availability zones: ${AZS[0]}, ${AZS[1]}, ${AZS[2]}"

# Create subnets for EKS in VPC1 (across multiple AZs)
echo "Creating subnets for VPC1 (EKS)..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id "$VPC1_ID" --cidr-block 10.0.0.0/24 --availability-zone "${AZS[0]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=eks-subnet-1}]' --query Subnet.SubnetId --output text)
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id "$VPC1_ID" --cidr-block 10.0.1.0/24 --availability-zone "${AZS[1]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=eks-subnet-2}]' --query Subnet.SubnetId --output text)
SUBNET3_ID=$(aws ec2 create-subnet --vpc-id "$VPC1_ID" --cidr-block 10.0.2.0/24 --availability-zone "${AZS[2]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=eks-subnet-3}]' --query Subnet.SubnetId --output text)

# Create subnets for NLB in VPC2 (across multiple AZs)
echo "Creating subnets for VPC2 (NLB)..."
SUBNET4_ID=$(aws ec2 create-subnet --vpc-id "$VPC2_ID" --cidr-block 10.1.0.0/24 --availability-zone "${AZS[0]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=nlb-subnet-1}]' --query Subnet.SubnetId --output text)
SUBNET5_ID=$(aws ec2 create-subnet --vpc-id "$VPC2_ID" --cidr-block 10.1.1.0/24 --availability-zone "${AZS[1]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=nlb-subnet-2}]' --query Subnet.SubnetId --output text)
SUBNET6_ID=$(aws ec2 create-subnet --vpc-id "$VPC2_ID" --cidr-block 10.1.2.0/24 --availability-zone "${AZS[2]}" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=nlb-subnet-3}]' --query Subnet.SubnetId --output text)

# Create Internet Gateways
echo "Creating Internet Gateways..."
IGW1_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=eks-igw}]' --query InternetGateway.InternetGatewayId --output text)
IGW2_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=nlb-igw}]' --query InternetGateway.InternetGatewayId --output text)

# Attach Internet Gateways to VPCs
echo "Attaching Internet Gateways to VPCs..."
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW1_ID" --vpc-id "$VPC1_ID"
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW2_ID" --vpc-id "$VPC2_ID"

# Create and configure route tables for VPC1
echo "Configuring route tables for VPC1..."
VPC1_RTB=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC1_ID" --query "RouteTables[0].RouteTableId" --output text)
aws ec2 create-tags --resources "$VPC1_RTB" --tags Key=Name,Value=eks-rtb
aws ec2 create-route --route-table-id "$VPC1_RTB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW1_ID"

# Create and configure route tables for VPC2
echo "Configuring route tables for VPC2..."
VPC2_RTB=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC2_ID" --query "RouteTables[0].RouteTableId" --output text)
aws ec2 create-tags --resources "$VPC2_RTB" --tags Key=Name,Value=nlb-rtb
aws ec2 create-route --route-table-id "$VPC2_RTB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW2_ID"

# Associate subnets with route tables
echo "Associating subnets with route tables..."
aws ec2 associate-route-table --route-table-id "$VPC1_RTB" --subnet-id "$SUBNET1_ID"
aws ec2 associate-route-table --route-table-id "$VPC1_RTB" --subnet-id "$SUBNET2_ID"
aws ec2 associate-route-table --route-table-id "$VPC1_RTB" --subnet-id "$SUBNET3_ID"

aws ec2 associate-route-table --route-table-id "$VPC2_RTB" --subnet-id "$SUBNET4_ID"
aws ec2 associate-route-table --route-table-id "$VPC2_RTB" --subnet-id "$SUBNET5_ID"
aws ec2 associate-route-table --route-table-id "$VPC2_RTB" --subnet-id "$SUBNET6_ID"

# Enable auto-assign public IP for subnets
echo "Enabling auto-assign public IP for subnets..."
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET1_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET2_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET3_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET4_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET5_ID" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET6_ID" --map-public-ip-on-launch

# Add EKS specific tags to VPC1 subnets
echo "Adding EKS specific tags to VPC1 subnets..."
CLUSTER_NAME="cross-vpc-demo"
aws ec2 create-tags --resources "$SUBNET1_ID" "$SUBNET2_ID" "$SUBNET3_ID" --tags Key=kubernetes.io/cluster/"$CLUSTER_NAME",Value=shared
aws ec2 create-tags --resources "$SUBNET1_ID" "$SUBNET2_ID" "$SUBNET3_ID" --tags Key=kubernetes.io/role/elb,Value=1

echo "VPC and subnet setup complete!"
echo "VPC1_ID=$VPC1_ID"
echo "VPC2_ID=$VPC2_ID"
echo "SUBNET1_ID=$SUBNET1_ID"
echo "SUBNET2_ID=$SUBNET2_ID"
echo "SUBNET3_ID=$SUBNET3_ID"
echo "SUBNET4_ID=$SUBNET4_ID"
echo "SUBNET5_ID=$SUBNET5_ID"
echo "SUBNET6_ID=$SUBNET6_ID"
echo "VPC1_RTB=$VPC1_RTB"
echo "VPC2_RTB=$VPC2_RTB"

# Save the IDs to a config file for other scripts to use
cat > vpc-config.env << EOF
export REGION=$REGION
export VPC1_ID=$VPC1_ID
export VPC2_ID=$VPC2_ID
export SUBNET1_ID=$SUBNET1_ID
export SUBNET2_ID=$SUBNET2_ID
export SUBNET3_ID=$SUBNET3_ID
export SUBNET4_ID=$SUBNET4_ID
export SUBNET5_ID=$SUBNET5_ID
export SUBNET6_ID=$SUBNET6_ID
export VPC1_RTB=$VPC1_RTB
export VPC2_RTB=$VPC2_RTB
export CLUSTER_NAME=$CLUSTER_NAME
EOF

echo "Configuration saved to vpc-config.env"
