# EKS Integrations

This directory contains setup scripts for various EKS plugins, controllers, and add-ons. Each subdirectory provides a self-contained installation script for a specific integration.

## Available Integrations

| Integration | Description | Use Case |
|-------------|-------------|----------|
| [AWS Load Balancer Controller](./aws-load-balancer-controller/) | Manages AWS Elastic Load Balancers for Kubernetes services | Ingress, LoadBalancer services |
| [AWS EBS CSI Driver](./aws-ebs-csi-driver/) | Manages EBS volumes for persistent storage | Persistent storage for stateful applications |
| [Cluster Autoscaler](./cluster-autoscaler/) | Automatically adjusts the size of the Kubernetes cluster | Workload-based cluster scaling |
| [Karpenter](./karpenter/) | Kubernetes node provisioning system | Just-in-time node provisioning |
| [NVIDIA GPU Operator](./nvidia-gpu-operator/) | Manages NVIDIA GPUs in Kubernetes | GPU workloads |
| [AppMesh Controller](./appmesh-controller/) | Manages AWS App Mesh resources | Service mesh for microservices |
| [CloudWatch Observability](./amazon-cloudwatch-observability/) | Provides observability with CloudWatch | Monitoring and logging |
| [Secrets Store CSI Driver](./secrets-store-csi-driver/) | Integrates with external secret stores | Secure secret management |
| [NVIDIA K8s Device Plugin](./nvidia-k8s-device-plugin/) | Exposes NVIDIA GPUs to Kubernetes | GPU workloads |
| [Ingress NGINX Controller](./ingress-nginx-controller/) | Implements Ingress with NGINX | HTTP/HTTPS routing |
| [EKS Pod Identity Agent](./eks-pod-identity-agent/) | Enables EKS Pod Identity | Fine-grained IAM permissions |
| [Trident CSI](./trident-csi/) | NetApp Trident CSI driver | Storage orchestration |
| [Kubecost](./kubecost/) | Cost monitoring for Kubernetes | Cost optimization |

## Usage

Each integration follows a similar pattern for installation:

```bash
cd <integration-directory>
./build.sh latest  # Use latest version
# OR
./build.sh <chart-version> <app-version>  # Specify versions
```

For example:

```bash
cd aws-load-balancer-controller
./build.sh 1.8.3 v2.8.3
```

## Integration Structure

Most integration directories contain:

- `build.sh`: Main installation script
- `policy.json`: IAM policy document (if required)
- Additional configuration files specific to the integration

## Prerequisites

Before installing any integration:

1. Ensure you have a running EKS cluster
2. Configure kubectl to use the correct context
3. Install required tools from the [toolkit directory](../../toolkit/)
4. Ensure you have appropriate IAM permissions

## Troubleshooting

If you encounter issues during installation:

1. Check that your AWS credentials are properly configured
2. Verify that your EKS cluster is running and accessible
3. Check for error messages in the build script output
4. Consult the official documentation for the specific integration
