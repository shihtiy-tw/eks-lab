# EKS Scenarios

This directory contains example implementations of various EKS use cases and scenarios. Each subdirectory demonstrates a specific implementation pattern or solution to a common challenge when working with Amazon EKS.

## Available Scenarios

| Category | Description | Key Scenarios |
|----------|-------------|--------------|
| [Load Balancers](./load-balancers/) | Examples of different load balancing configurations | ALB with HTTPS, NLB, hostname routing, graceful shutdown |
| [Karpenter](./karpenter/) | Demonstrations of Karpenter node provisioning | General usage, AL2023 examples |
| [Java Optimization](./java-memory/) | Java application optimization techniques | Memory management, DirectBuffer, AlwaysPreTouch |
| [Fargate Logging](./fargate-nginx-logging/) | Logging configurations for Fargate | CloudWatch, OpenSearch |
| [IRSA](./irsa/) | IAM Roles for Service Accounts examples | S3 access, cross-account access |
| [GPU Workloads](./nvidia-gpu/) | Running GPU workloads on EKS | CUDA applications, ML workloads |
| [Custom Networking](./custom-network/) | Custom networking configurations | VPC CNI customization, network policies |
| [Windows Workloads](./windows/) | Running Windows containers on EKS | .NET applications, Windows node groups |
| [Auto Mode](./auto-mode/) | Automatic scaling and provisioning | Custom node configurations |
| [CloudWatch](./cloudwatch-observability/) | CloudWatch integration examples | Metrics, logs, traces |
| [AppMesh](./appmesh/) | Service mesh implementations | Microservices communication |
| [Pod Identity](./pod-identity/) | EKS Pod Identity examples | S3 access with Pod Identity |

## Usage

Each scenario typically includes:

1. Kubernetes manifests (YAML files)
2. Shell scripts for deployment
3. Documentation on the specific use case
4. Configuration examples

To deploy a scenario:

```bash
cd <scenario-directory>
./build.sh  # Follow the instructions in the script
```

For example:

```bash
cd load-balancers/alb-https
./build.sh
```

## Prerequisites

Before running any scenario:

1. Ensure you have a running EKS cluster
2. Install any required integrations from the [integrations directory](../integrations/)
3. Configure kubectl to use the correct context
4. Review the scenario documentation for specific requirements

## Scenario Structure

Most scenario directories contain:

- `build.sh`: Deployment script
- Kubernetes manifest files (`.yaml`)
- `README.md`: Specific documentation for the scenario
- Additional configuration files as needed

## Learning Path

If you're new to EKS, consider exploring the scenarios in this order:

1. Basic load balancing examples
2. Auto-scaling with Karpenter
3. IRSA for secure AWS service access
4. Logging and monitoring configurations
5. Advanced networking and specialized workloads
