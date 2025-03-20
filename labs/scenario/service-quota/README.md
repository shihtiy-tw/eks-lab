
```bash
$ kubectl get quota -n resource-quota -o yaml
apiVersion: v1
items:
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"v1","kind":"ResourceQuota","metadata":{"annotations":{},"name":"resource-quota-compute-resources","namespace":"resource-quota"},"spec":{"hard":{"limits.cpu":"2","limits.memory":"2Gi","requests.cpu":"1","requests.memory":"1Gi","requests.nvidia.com/gpu":4}}}
    creationTimestamp: "2025-01-03T10:53:04Z"
    name: resource-quota-compute-resources
    namespace: resource-quota
    resourceVersion: "31026872"
    uid: 853cb246-e62d-4028-8287-17ed0de0fea1
  spec:
    hard:
      limits.cpu: "2"
      limits.memory: 2Gi
      requests.cpu: "1"
      requests.memory: 1Gi
      requests.nvidia.com/gpu: "4"
  status:
    hard:
      limits.cpu: "2"
      limits.memory: 2Gi
      requests.cpu: "1"
      requests.memory: 1Gi
      requests.nvidia.com/gpu: "4"
    used:
      limits.cpu: "0"
      limits.memory: "0"
      requests.cpu: "0"
      requests.memory: "0"
      requests.nvidia.com/gpu: "0"
kind: List
metadata:
  resourceVersion: ""

$ kubectl describe quota -n resource-quota
Name:                    resource-quota-compute-resources
Namespace:               resource-quota
Resource                 Used  Hard
--------                 ----  ----
limits.cpu               0     2
limits.memory            0     2Gi
requests.cpu             0     1
requests.memory          0     1Gi
requests.nvidia.com/gpu  0     4

$ kubectl describe ns resource-quota
Name:         resource-quota
Labels:       kubernetes.io/metadata.name=resource-quota
              name=resource-quota
Annotations:  <none>
Status:       Active

Resource Quotas
  Name:                    resource-quota-compute-resources
  Resource                 Used  Hard
  --------                 ---   ---
  limits.cpu               0     2
  limits.memory            0     2Gi
  requests.cpu             0     1
  requests.memory          0     1Gi
  requests.nvidia.com/gpu  0     4

No LimitRange resource.
```
