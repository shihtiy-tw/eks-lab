#!/bin/bash

# Source common configuration
source ../config.sh

# Set variables
NAMESPACE="monitoring"
REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2)
WORKSPACE_NAME="${CLUSTER_NAME}-prometheus"
GRAFANA_NAME="${CLUSTER_NAME}-grafana"

# Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Creating AWS Managed Prometheus workspace..."
# Check if workspace already exists
WORKSPACE_ARN=$(aws amp list-workspaces --query "workspaces[?alias=='${WORKSPACE_NAME}'].workspaceId" --output text)

if [ -z "$WORKSPACE_ARN" ] || [ "$WORKSPACE_ARN" == "None" ]; then
  # Create new AMP workspace
  WORKSPACE_ARN=$(aws amp create-workspace --alias ${WORKSPACE_NAME} --query workspaceId --output text)
  echo "Created new AMP workspace: ${WORKSPACE_ARN}"
else
  echo "Using existing AMP workspace: ${WORKSPACE_ARN}"
fi

# Get the AMP endpoint
AMP_ENDPOINT=$(aws amp describe-workspace --workspace-id ${WORKSPACE_ARN} --query workspace.prometheusEndpoint --output text)
AMP_REMOTE_WRITE_URL="${AMP_ENDPOINT}api/v1/remote_write"

echo "Setting up IAM role for Prometheus..."
# Create IAM role for service account
eksctl create iamserviceaccount \
  --name amp-iamproxy-service-account \
  --namespace ${NAMESPACE} \
  --cluster ${CLUSTER_NAME} \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess \
  --approve \
  --override-existing-serviceaccounts

# Install kube-state-metrics
echo "Installing kube-state-metrics..."
kubectl apply -f kube-state-metrics.yaml

# Install node-exporter
echo "Installing node-exporter..."
kubectl apply -f node-exporter.yaml

# Install AWS Distro for OpenTelemetry (ADOT) Operator
echo "Installing ADOT Operator..."
kubectl apply -f https://amazon-eks.s3.amazonaws.com/docs/addons/adot/latest/adot-operator.yaml

# Wait for ADOT CRDs to be available
echo "Waiting for ADOT CRDs to be available..."
kubectl wait --for condition=established --timeout=60s crd/opentelemetrycollectors.opentelemetry.io

# Create ADOT Collector for Prometheus
echo "Creating ADOT Collector for EKS metrics collection..."
# Replace placeholders in the collector config
sed "s|\${AMP_REMOTE_WRITE_URL}|${AMP_REMOTE_WRITE_URL}|g; s|\${REGION}|${REGION}|g" eks-scraper-config.yaml | kubectl apply -f -

echo "Creating Amazon Managed Grafana workspace..."
# Check if Grafana workspace already exists
GRAFANA_ID=$(aws grafana list-workspaces --query "workspaces[?name=='${GRAFANA_NAME}'].id" --output text)

if [ -z "$GRAFANA_ID" ] || [ "$GRAFANA_ID" == "None" ]; then
  # Create IAM role for Grafana
  ROLE_NAME="AmazonGrafanaServiceRole-${GRAFANA_NAME}"
  
  # Check if role exists
  ROLE_EXISTS=$(aws iam get-role --role-name ${ROLE_NAME} 2>&1 || echo "not_exists")
  
  if [[ $ROLE_EXISTS == *"not_exists"* ]]; then
    # Create trust policy
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "grafana.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create role
    ROLE_ARN=$(aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://trust-policy.json --query Role.Arn --output text)
    
    # Attach policies
    aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess
    aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess
    aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
    
    # Clean up
    rm trust-policy.json
  else
    ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query Role.Arn --output text)
  fi
  
  # Create Grafana workspace
  GRAFANA_ID=$(aws grafana create-workspace \
    --name ${GRAFANA_NAME} \
    --account-access-type CURRENT_ACCOUNT \
    --authentication-providers AWS_SSO \
    --permission-type SERVICE_MANAGED \
    --role-arn ${ROLE_ARN} \
    --data-sources PROMETHEUS \
    --query id --output text)
  
  echo "Created new Grafana workspace: ${GRAFANA_ID}"
else
  echo "Using existing Grafana workspace: ${GRAFANA_ID}"
fi

# Get Grafana URL
GRAFANA_URL=$(aws grafana describe-workspace --workspace-id ${GRAFANA_ID} --query workspace.endpoint --output text)
GRAFANA_URL="https://${GRAFANA_URL}"

# Wait for the collector to be ready
echo "Waiting for ADOT collector to be ready..."
kubectl wait --for=condition=Ready --timeout=120s -n ${NAMESPACE} pod -l app.kubernetes.io/component=opentelemetry-collector

echo "Waiting for kube-state-metrics to be ready..."
kubectl wait --for=condition=Ready --timeout=120s -n ${NAMESPACE} pod -l app.kubernetes.io/name=kube-state-metrics

echo "Waiting for node-exporter to be ready..."
kubectl wait --for=condition=Ready --timeout=120s -n ${NAMESPACE} pod -l app.kubernetes.io/name=node-exporter

# Configure Grafana data source for AMP
echo "To complete setup:"
echo "1. Access your Grafana workspace at: ${GRAFANA_URL}"
echo "2. Add Amazon Managed Prometheus as a data source with:"
echo "   - Name: AMP"
echo "   - Service: Prometheus"
echo "   - Prometheus server URL: ${AMP_ENDPOINT}api/v1/query"
echo "   - Auth Provider: AWS SDK Default"
echo "   - Region: ${REGION}"
echo "   - Workspace ID: ${WORKSPACE_ARN}"
echo ""
echo "AWS Managed Prometheus workspace ARN: ${WORKSPACE_ARN}"
echo "Amazon Managed Grafana workspace URL: ${GRAFANA_URL}"
echo ""
echo "Note: You need to configure AWS SSO to access the Grafana workspace."
echo ""
echo "The following metrics collectors have been installed:"
echo "- kube-state-metrics: Provides cluster-level metrics about the state of Kubernetes objects"
echo "- node-exporter: Provides hardware and OS metrics from each node"
echo "- ADOT Collector: Scrapes and forwards metrics to AWS Managed Prometheus"
