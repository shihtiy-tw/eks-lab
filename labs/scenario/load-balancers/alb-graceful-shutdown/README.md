## Deploy

```bash
$ kustomize build . | kubectl apply -f -
$ kustomize build . | kubectl delete -f -
```

## Consideration

I cannot find a way to make kustomize change the key in annotation key:

```
    alb.ingress.kubernetes.io/actions.graceful-shutdown-nginx-service: >
      {"type":"forward","forwardConfig":{"targetGroups":[{"serviceName":"graceful-shutdown-nginx-service","servicePort":"80"}]}}
```

This need to changed manually to match the service name.
