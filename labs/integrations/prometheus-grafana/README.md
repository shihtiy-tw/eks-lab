# AWS Managed Prometheus and Grafana Integration for EKS

This integration sets up AWS Managed Prometheus (AMP) and Amazon Managed Grafana (AMG) for your EKS cluster, along with comprehensive metrics collection.

## Components

- **AWS Managed Prometheus (AMP)**: A fully managed Prometheus-compatible monitoring service
- **Amazon Managed Grafana (AMG)**: A fully managed Grafana service for data visualization
- **AWS Distro for OpenTelemetry (ADOT)**: Collector to scrape metrics and send to AMP
- **kube-state-metrics**: Provides cluster-level metrics about the state of Kubernetes objects
- **node-exporter**: Provides hardware and OS metrics from each node

## Prerequisites

- AWS CLI configured with appropriate permissions
- EKS cluster running
- `eksctl` installed
- AWS SSO configured (for Grafana access)

## Installation

Run the build script to set up AMP and AMG:

```bash
./build.sh
```

The script performs the following actions:
1. Creates an AWS Managed Prometheus workspace
2. Sets up IAM roles and service accounts for Prometheus
3. Installs kube-state-metrics for cluster-level metrics
4. Installs node-exporter for node-level metrics
5. Installs the AWS Distro for OpenTelemetry (ADOT) Operator
6. Configures an ADOT Collector to scrape metrics and send to AMP
7. Creates an Amazon Managed Grafana workspace
8. Provides instructions for completing the setup

## Metrics Collection

This integration collects the following metrics:

1. **Kubernetes API Server Metrics**
   - API request rates and latencies
   - etcd interaction metrics
   - Resource usage

2. **Node Metrics (via node-exporter)**
   - CPU, memory, disk usage
   - Network traffic
   - System load
   - File system metrics

3. **Kubernetes State Metrics**
   - Deployment status and replicas
   - Pod status and resource requests/limits
   - Service endpoints
   - ConfigMap and Secret counts
   - Job completions and failures

4. **Container Metrics (via cAdvisor)**
   - Container CPU and memory usage
   - Network I/O
   - Disk I/O

5. **Application Metrics**
   - Custom metrics from applications with Prometheus annotations

## Access Grafana

After installation, you'll need to:

1. Access your Grafana workspace using the URL provided by the script
2. Log in using AWS SSO
3. Add Amazon Managed Prometheus as a data source with the details provided

## Monitoring Applications

To monitor applications, add the following annotations to your pod specs:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: /metrics
  prometheus.io/port: "8080"
```

## Uninstallation

To uninstall the components:

```bash
# Delete ADOT Collector
kubectl delete -n monitoring OpenTelemetryCollector/eks-amp-collector

# Delete node-exporter
kubectl delete -f node-exporter.yaml

# Delete kube-state-metrics
kubectl delete -f kube-state-metrics.yaml

# Delete ADOT Operator
kubectl delete -f https://amazon-eks.s3.amazonaws.com/docs/addons/adot/latest/adot-operator.yaml

# Delete service account
eksctl delete iamserviceaccount --name amp-iamproxy-service-account --namespace monitoring --cluster <your-cluster-name>

# Delete namespace
kubectl delete namespace monitoring

# Delete AMP workspace (optional)
aws amp delete-workspace --workspace-id <workspace-id>

# Delete AMG workspace (optional)
aws grafana delete-workspace --workspace-id <workspace-id>
```

## Additional Resources

- [Amazon Managed Service for Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Documentation](https://docs.aws.amazon.com/grafana/)
- [AWS Distro for OpenTelemetry Documentation](https://aws-otel.github.io/)
- [kube-state-metrics Documentation](https://github.com/kubernetes/kube-state-metrics)
- [node-exporter Documentation](https://github.com/prometheus/node_exporter)
