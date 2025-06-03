# AWS Managed Prometheus and Grafana Scenario

This scenario demonstrates how to monitor applications in EKS using AWS Managed Prometheus and Amazon Managed Grafana.

## Prerequisites

1. Install the AWS Managed Prometheus and Grafana integration:
   ```bash
   cd /home/ubuntu/eks-lab/labs/integrations/prometheus-grafana
   ./build.sh
   ```

2. Wait for the ADOT Collector to be ready:
   ```bash
   kubectl get pods -n monitoring
   ```

## Deploy Sample Application

1. Create the namespace:
   ```bash
   kubectl apply -f k8s-namespace.yaml
   ```

2. Deploy the sample application:
   ```bash
   kubectl apply -f k8s-deployment-sample-app.yaml
   ```

## Access Grafana and View Metrics

1. Get the Grafana URL:
   ```bash
   CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2)
   GRAFANA_NAME="${CLUSTER_NAME}-grafana"
   GRAFANA_ID=$(aws grafana list-workspaces --query "workspaces[?name=='${GRAFANA_NAME}'].id" --output text)
   GRAFANA_URL=$(aws grafana describe-workspace --workspace-id $GRAFANA_ID --query workspace.endpoint --output text)
   echo "https://${GRAFANA_URL}"
   ```

2. Log in to Grafana using AWS SSO

3. Create a dashboard to visualize metrics:
   - Click on "Create" > "Dashboard"
   - Add a new panel
   - Use queries like:
     - `rate(container_cpu_usage_seconds_total{namespace="prometheus-demo", pod=~"sample-app.*"}[5m])`
     - `container_memory_usage_bytes{namespace="prometheus-demo", pod=~"sample-app.*"}`

## Creating a Dashboard

Here are some useful queries for your dashboard:

1. **CPU Usage by Pod**:
   ```
   sum(rate(container_cpu_usage_seconds_total{namespace="prometheus-demo", pod=~"sample-app.*"}[5m])) by (pod)
   ```

2. **Memory Usage by Pod**:
   ```
   sum(container_memory_usage_bytes{namespace="prometheus-demo", pod=~"sample-app.*"}) by (pod)
   ```

3. **Network Receive Bytes**:
   ```
   sum(rate(container_network_receive_bytes_total{namespace="prometheus-demo", pod=~"sample-app.*"}[5m])) by (pod)
   ```

4. **Network Transmit Bytes**:
   ```
   sum(rate(container_network_transmit_bytes_total{namespace="prometheus-demo", pod=~"sample-app.*"}[5m])) by (pod)
   ```

## Cleanup

To remove the sample application:

```bash
kubectl delete -f k8s-deployment-sample-app.yaml
kubectl delete -f k8s-namespace.yaml
```

To uninstall AWS Managed Prometheus components:

```bash
# Delete ADOT Collector
kubectl delete -n monitoring OpenTelemetryCollector/amp-collector

# Delete ADOT Operator
kubectl delete -f https://amazon-eks.s3.amazonaws.com/docs/addons/adot/latest/adot-operator.yaml

# Delete service account
CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2)
eksctl delete iamserviceaccount --name amp-iamproxy-service-account --namespace monitoring --cluster ${CLUSTER_NAME}

# Delete namespace
kubectl delete namespace monitoring
```

Note: AWS Managed Prometheus and Amazon Managed Grafana workspaces will continue to exist and incur charges unless explicitly deleted through the AWS CLI or console.
