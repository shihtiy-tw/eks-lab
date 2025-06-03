#!/bin/bash

# Apply all resources for the AWS Managed Prometheus and Grafana scenario

# Create namespace
kubectl apply -f k8s-namespace.yaml

# Deploy sample application
kubectl apply -f k8s-deployment-sample-app.yaml

echo "Sample application deployed for AWS Managed Prometheus monitoring"
echo ""
echo "The application is annotated with Prometheus scraping configurations:"
echo "  prometheus.io/scrape: \"true\""
echo "  prometheus.io/path: /metrics"
echo "  prometheus.io/port: \"8080\""
echo ""
echo "Metrics will be collected by the ADOT collector and sent to AWS Managed Prometheus"
echo "You can view these metrics in your Amazon Managed Grafana workspace"
echo ""
echo "To get your Grafana URL, run:"
echo "  CLUSTER_NAME=\$(kubectl config current-context | cut -d'/' -f2)"
echo "  GRAFANA_NAME=\"\${CLUSTER_NAME}-grafana\""
echo "  GRAFANA_ID=\$(aws grafana list-workspaces --query \"workspaces[?name=='\${GRAFANA_NAME}'].id\" --output text)"
echo "  aws grafana describe-workspace --workspace-id \$GRAFANA_ID --query workspace.endpoint --output text"
