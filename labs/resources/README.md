# EKS Resources

This directory contains configuration files and templates for EKS clusters, nodegroups, launch templates, and other resources. These files serve as reference implementations and starting points for creating and managing EKS infrastructure.

## Directory Structure

```
resources/
├── clusters/         # EKS cluster configurations
├── config/           # Configuration files for EKS components
├── custom-amis/      # Custom AMI definitions and configurations
├── launch-templates/ # EC2 launch templates for EKS nodes
├── nodegroups/       # EKS nodegroup definitions
├── scripts/          # Utility scripts for resource management
└── versions/         # Version-specific configurations
```

## Key Components

### Clusters

The `clusters` directory contains example configurations for creating EKS clusters with different settings and features. These examples demonstrate:

- Cluster creation with eksctl
- Custom networking configurations
- Control plane logging options
- Cluster add-on configurations

### Nodegroups

The `nodegroups` directory provides examples for different types of EKS nodegroups:

- Managed nodegroups
- Self-managed nodegroups
- Spot instance nodegroups
- GPU-enabled nodegroups
- Windows nodegroups

### Launch Templates

The `launch-templates` directory contains EC2 launch template configurations for EKS nodes, including:

- AL2023 optimized templates
- Custom user data scripts
- Instance type selections
- Storage configurations

### Custom AMIs

The `custom-amis` directory provides examples for creating and using custom AMIs with EKS, including:

- AMI customization scripts
- Packer templates
- Post-installation configurations

## Usage

### Listing Resources

To list all clusters and nodegroups:

```bash
../scripts/list-cluster-nodegroup.sh
```

Or use the Makefile from the root directory:

```bash
make list
```

### Creating Resources

The configuration files in this directory can be used as references when creating your own EKS resources. For example:

```bash
# Create a cluster using eksctl
eksctl create cluster -f clusters/example-cluster.yaml

# Create a nodegroup
eksctl create nodegroup -f nodegroups/example-nodegroup.yaml
```

## Best Practices

When working with EKS resources:

1. Always use Infrastructure as Code (IaC) to define and manage resources
2. Follow the principle of least privilege for IAM roles and policies
3. Use tagging for resource organization and cost allocation
4. Consider using managed nodegroups for simplified operations
5. Implement proper networking and security configurations

## Prerequisites

Before creating EKS resources:

1. Install required tools from the [toolkit directory](../../toolkit/)
2. Configure AWS credentials with appropriate permissions
3. Understand the AWS and Kubernetes resource model
4. Plan your networking and security requirements
