# Cross-VPC Load Balancing

This directory contains infrastructure setup scripts for a cross-VPC load balancing scenario with EKS and NLB.

## Use Case

This setup demonstrates how to:
- Create two VPCs with VPC peering
- Deploy an EKS cluster in one VPC
- Deploy a Network Load Balancer (NLB) in another VPC
- Configure the AWS Load Balancer Controller to use the NLB in the second VPC
- Register pod IPs from the EKS cluster with the NLB in the second VPC

This pattern can be useful when:
- You need to separate your compute resources from your load balancers
- You have a dedicated networking VPC for all ingress/egress traffic
- You want to centralize your load balancers in a single VPC
- You need to implement specific security controls at the VPC level

## Components

- **vpc-peering/**: Scripts to set up two VPCs with peering connection
- **eks-nlb/**: Scripts to set up an EKS cluster in VPC1 and an NLB in VPC2

## Usage

1. Set up the VPCs and VPC peering:
   ```bash
   cd vpc-peering
   ./setup-vpcs.sh
   ./setup-vpc-peering.sh
   ```

2. Set up the EKS cluster and NLB:
   ```bash
   cd ../eks-nlb
   ./setup-eks.sh
   ./setup-nlb.sh
   ```

3. Deploy the application and configure the AWS Load Balancer Controller:
   ```bash
   cd ../../../scenario/load-balancers/cross-vpc-nlb
   ./build.sh
   ```

## Architecture Diagram

```
┌───────────────────────┐     ┌───────────────────────┐
│                       │     │                       │
│       VPC1 (EKS)      │     │       VPC2 (NLB)      │
│                       │     │                       │
│  ┌─────────────────┐  │     │  ┌─────────────────┐  │
│  │                 │  │     │  │                 │  │
│  │   EKS Cluster   │  │     │  │       NLB       │  │
│  │                 │  │     │  │                 │  │
│  └────────┬────────┘  │     │  └────────┬────────┘  │
│           │           │◄────┼───────────┘           │
│           │           │     │                       │
│  ┌────────▼────────┐  │     │  ┌─────────────────┐  │
│  │                 │  │     │  │                 │  │
│  │   Pod IPs       │◄─┼─────┼──┤ Target Group    │  │
│  │                 │  │     │  │                 │  │
│  └─────────────────┘  │     │  └─────────────────┘  │
│                       │     │                       │
└───────────────────────┘     └───────────────────────┘
         │                               ▲
         │                               │
         │                               │
         └───────────────────────────────┘
                   VPC Peering
```

## Cleanup

To clean up all resources, follow these steps:

1. Delete the Kubernetes resources:
   ```bash
   cd ../../../scenario/load-balancers/cross-vpc-nlb
   kubectl delete -f k8s-targetgroupbinding.yaml
   kubectl delete -f k8s-service.yaml
   kubectl delete -f k8s-deployment-sample-app.yaml
   kubectl delete -f k8s-namespace.yaml
   ```

2. Delete the EKS cluster and NLB:
   ```bash
   cd ../../../resources/cross-vpc-loadbalancing/eks-nlb
   # Follow cleanup instructions in README.md
   ```

3. Delete the VPCs and VPC peering:
   ```bash
   cd ../vpc-peering
   # Follow cleanup instructions in README.md
   ```
