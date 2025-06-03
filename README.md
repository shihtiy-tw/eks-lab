# EKS Lab - Comprehensive Examples for Amazon EKS

This repository contains a collection of labs, examples, and configurations for common Amazon Elastic Kubernetes Service (EKS) use cases. It serves as a practical guide for implementing various EKS features, integrations, and scenarios.

## Overview

The EKS Lab project provides:
- Ready-to-use integration scripts for popular EKS add-ons and controllers
- Practical scenarios demonstrating real-world EKS implementations
- Configuration examples for clusters, nodegroups, and resources
- Step-by-step guides for common EKS operations

## Setup

Install required tools. See [Toolkit README](./toolkit/README.md).

## Repository Structure

```
.
├── labs/
│   ├── resources/         # EKS cluster configurations and resources
│   ├── integrations/      # Setup scripts for EKS plugins and controllers
│   └── scenario/          # Example implementations of various EKS use cases
├── toolkit/               # Utility scripts and setup instructions
├── Makefile               # Helper commands for common operations
└── README.md              # This file
```

### Key Components

- **Resources**: Contains configurations for clusters, nodegroups, launch templates, and custom AMIs.
- **Integrations**: Includes setup scripts for various controllers like AWS Load Balancer Controller, EBS CSI Driver, Karpenter, etc.
- **Scenarios**: Demonstrates specific use cases such as load balancing, auto-scaling, GPU workloads, custom networking, and more.
- **Toolkit**: Provides utility scripts and setup instructions for required tools.

## Usage

### Working with Integrations

To install an integration (e.g., AWS Load Balancer Controller):

```bash
cd labs/integrations/aws-load-balancer-controller
./build.sh latest  # Use latest version
# OR
./build.sh 1.8.3 v2.8.3  # Specify chart and app versions
```

### Exploring Scenarios

To deploy a scenario (e.g., ALB with HTTPS):

```bash
cd labs/scenario/load-balancers/alb-https
./build.sh  # Follow the instructions in the script
```

### Listing Resources

To list all clusters and nodegroups:

```bash
make list
```

## Available Integrations

- AWS Load Balancer Controller
- AWS EBS CSI Driver
- Cluster Autoscaler
- Karpenter
- NVIDIA GPU Operator
- AppMesh Controller
- CloudWatch Observability
- Secrets Store CSI Driver
- And many more

## Scenario Examples

- Load balancer configurations (ALB/NLB)
- Auto-scaling with Karpenter
- GPU workloads
- Java application optimization
- Fargate logging
- IRSA (IAM Roles for Service Accounts)
- Custom networking
- Windows workloads

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Inspired by

- [guessi/eks-integrations-quick-start](https://github.com/guessi/eks-integrations-quick-start)
- [guessi/eks-tutorials](https://github.com/guessi/eks-tutorials)

<!-- TODO: Add pre-commit for aws account and credential -->
