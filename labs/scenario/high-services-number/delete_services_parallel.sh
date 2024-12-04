#!/bin/bash

# List all the services named my-service-*
kubectl get svc -o custom-columns=":metadata.name" | grep 'my-service-' | xargs -I {} -P 10 kubectl delete svc {}

