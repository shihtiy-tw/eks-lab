## Overview

A EKS cluster takes around 15 minutes to setup.

## Cluster Types

- minimal
- full

### Minimal Cluster

- Control Plane logging
- Fargate profile
- Addon:
  - VPC CNI Plugin
  - kube-proxy
  - CoreDNS

### Full Cluster

- Control Plane logging
- Fargate profile
- Addon:
  - VPC CNI Plugin
  - kube-proxy
  - CoreDNS
  - EBS CSI Driver
  - EFS CSI Driver
  - EKS Pod Identity Agent
  - CloudWatch Obervability
- IAM Service Account

## Getting started

This script (`setup.sh`) automates the process of setting up an Amazon EKS (Elastic Kubernetes Service) cluster. It provides a flexible way to configure cluster parameters and supports different cluster configurations.

## Usage

### Clusters

```bash
$ ./setup.sh cluster [CLUSTER_VERSION] [REGION] [CONFIG_TYPE]
$ ./setup.sh cluster 1.29 us-east-2 minimal
```

1. CLUSTER_NAME (optional): Name of the EKS cluster. If not provided, defaults to "EKS-Lab-VERSION".
2. REGION (optional): AWS region to deploy the cluster. Defaults to "us-east-1" if not specified.
3. CONFIG_TYPE (optional): Type of cluster configuration. Options are:
   - full: Full cluster setup (default)
   - minimal: Minimal cluster configuration
   - ipv6: Cluster with IPv6 support
   - private: Private cluster configuration

### Nodegroup

```bash
$ ./setup.sh managed-nodegroup [CLUSTER_VERSION] [REGION] [CLUSTER_CONFIG_TYPE] [NODEGROUP_CONFIG] [NODEGROUP_SIZE]
$ ./setup.sh managed-nodegroup 1.29 us-west-1 minimal on-demand m5.large
```

## Tool

### VSCode

eksctl schema

```bash
eksctl utils schema
```

yaml-language-server

```yaml
# yaml-language-server: $schema=<path to eksctl scheme>
```
