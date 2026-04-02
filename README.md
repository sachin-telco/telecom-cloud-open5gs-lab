# telecom-cloud-open5gs-lab

Step 0 baseline completed.

## Current baseline
- Git repository initialized and connected to GitHub
- kind cluster definition stored in Git
- Local kind cluster recreated successfully
- telecom namespace managed via manifest
- smoke-nginx deployment running in telecom namespace
- smoke-nginx service reachable inside cluster

## Quick validation commands
kubectl get nodes
kubectl get ns telecom
kubectl get deploy,svc -n telecom
kubectl run curl-test -n telecom --image=curlimages/curl:8.10.1 --restart=Never --rm -it -- curl -I http://smoke-nginx

## Step 0 goal
Create a reproducible, Git-driven Kubernetes baseline before deploying telecom workloads like Open5GS.
