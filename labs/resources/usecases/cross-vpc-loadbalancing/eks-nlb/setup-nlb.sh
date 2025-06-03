#!/bin/bash

# Exit on error
set -e

# Source the VPC configuration
source ../vpc-peering/vpc-config.env

echo "Setting up Network Load Balancer in VPC2 ($VPC2_ID)..."

# Create target group in VPC2
TG_NAME="cross-vpc-target-group"
echo "Creating target group $TG_NAME..."
TG_ARN=$(aws elbv2 create-target-group \
  --name $TG_NAME \
  --protocol TCP \
  --port 80 \
  --vpc-id $VPC2_ID \
  --target-type ip \
  --health-check-protocol TCP \
  --health-check-port 80 \
  --health-check-enabled \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 10 \
  --healthy-threshold-count 3 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target group created: $TG_ARN"

# Create NLB in VPC2
NLB_NAME="cross-vpc-nlb"
echo "Creating Network Load Balancer $NLB_NAME..."
NLB_ARN=$(aws elbv2 create-load-balancer \
  --name $NLB_NAME \
  --type network \
  --subnets $SUBNET4_ID $SUBNET5_ID $SUBNET6_ID \
  --scheme internet-facing \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "Network Load Balancer created: $NLB_ARN"

# Get NLB DNS name
NLB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $NLB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "NLB DNS Name: $NLB_DNS"

# Create listener
echo "Creating listener on port 80..."
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $NLB_ARN \
  --protocol TCP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Listener created: $LISTENER_ARN"

# Save NLB configuration
echo "Saving NLB configuration..."
cat > nlb-config.env << EOF
export TARGET_GROUP_ARN=$TG_ARN
export NLB_ARN=$NLB_ARN
export NLB_DNS=$NLB_DNS
export LISTENER_ARN=$LISTENER_ARN
EOF

echo "NLB setup complete!"
echo "NLB DNS Name: $NLB_DNS"
echo "Target Group ARN: $TG_ARN"
