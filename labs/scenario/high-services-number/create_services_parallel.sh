#!/bin/bash

# May need large c5 instance type to accerlate the lab.

create_service() {
  local i=$1
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: my-service-$i
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
EOF
}

export -f create_service

#seq 1 5000 | xargs -n 1 -P 10 -I {} bash -c 'create_service "$@"' _ {}
#seq 1194 5000 | xargs -n 1 -P 100 -I {} bash -c 'create_service "$@"' _ {}
seq 5000 10000 | xargs -n 1 -P 100 -I {} bash -c 'create_service "$@"' _ {}
