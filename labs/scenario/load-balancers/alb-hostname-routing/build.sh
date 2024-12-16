#!/bin/bash

# $ ./build.sh
# $ kustomize build . | kubectl delete -f -

APACHE_SERVICE_NAME=$(yq -r ".metadata.name" k8s-service-apache.yaml)
NGINX_SERVICE_NAME=$(yq -r ".metadata.name" k8s-service-nginx.yaml)
NAME_PREFIX=$(yq -r ".namePrefix" kustomization.yaml)

kustomize build . \
  | sed -e "/annotations:/,/spec:/s/${APACHE_SERVICE_NAME}/${NAME_PREFIX}${APACHE_SERVICE_NAME}/g" \
  | sed -e "/annotations:/,/spec:/s/${NGINX_SERVICE_NAME}/${NAME_PREFIX}${NGINX_SERVICE_NAME}/g" \
  | kubectl apply -f -
