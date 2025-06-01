# Karpenter on EKS

This directory contains examples and configurations for using Karpenter with Amazon EKS. Karpenter is an open-source node provisioning project that improves the efficiency and cost of running workloads on Kubernetes clusters.

## Overview

Karpenter automatically launches just the right compute resources to handle your cluster's applications. It's designed to let you take full advantage of the cloud with fast and simple compute provisioning for Kubernetes clusters.

## Prerequisites

Before running these examples, ensure you have:

1. A running EKS cluster
2. [Karpenter controller](../../integrations/karpenter/) installed on your cluster
3. Appropriate IAM permissions for Karpenter to provision EC2 instances
4. AWS credentials configured

## Directory Structure

```
karpenter/
├── al2023/           # Examples specific to Amazon Linux 2023
├── general/          # General Karpenter examples
└── README.md         # This file
```

## Available Examples

### General Examples

The `general` directory contains basic Karpenter configurations:

- NodePool and EC2NodeClass resources
- Deployment examples that trigger Karpenter provisioning
- Consolidation configurations for cost optimization

### Amazon Linux 2023 Examples

The `al2023` directory demonstrates:

- Using AL2023 as the node operating system
- Optimized configurations for AL2023
- Custom AMI settings

## Key Concepts

### NodePool

NodePool resources define groups of nodes that Karpenter can provision:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
```

### EC2NodeClass

EC2NodeClass resources define the EC2-specific configuration:

```yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelector:
    karpenter.sh/discovery: "true"
  securityGroupSelector:
    karpenter.sh/discovery: "true"
```

## Usage

To deploy an example:

```bash
cd <example-directory>
kubectl apply -f nodepool.yaml
kubectl apply -f ec2nodeclass.yaml
kubectl apply -f deployment.yaml
```

## Monitoring Karpenter

To view Karpenter logs:

```bash
kubectl logs -n karpenter deployment/karpenter -c controller
```

To view provisioned nodes:

```bash
kubectl get nodes -l karpenter.sh/provisioner-name
```

## Best Practices

1. Use spot instances for cost savings where appropriate
2. Configure consolidation for efficient resource usage
3. Set appropriate resource limits to prevent over-provisioning
4. Use node selectors and taints for workload placement
5. Monitor Karpenter metrics for performance and cost optimization

## Additional Resources

- [Karpenter Documentation](https://karpenter.sh/docs/)
- [AWS EKS Workshop - Karpenter](https://www.eksworkshop.com/docs/autoscaling/compute/karpenter/)
- [Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
