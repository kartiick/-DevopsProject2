#!/bin/bash
# This script retrieves the ArgoCD, Prometheus, and Grafana URLs and credentials from an EKS cluster.

set -e

REGION="us-east-1"
CLUSTER_NAME="amazon-prime-cluster"

echo "[*] Updating kubeconfig for EKS cluster: $CLUSTER_NAME in region $REGION..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Function to wait for LoadBalancer hostname to be available
wait_for_hostname() {
  local namespace=$1
  local service=$2
  echo "[*] Waiting for LoadBalancer hostname for $service in $namespace..."
  while true; do
    host=$(kubectl get svc -n "$namespace" "$service" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [[ -n "$host" ]]; then
      echo "$host"
      break
    fi
    echo "    -> LoadBalancer not ready yet. Retrying in 10 seconds..."
    sleep 10
  done
}

echo
echo "[*] Fetching ArgoCD credentials..."
argo_url=$(wait_for_hostname "argocd" "argocd-server")
argo_user="admin"
argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

echo "[*] Fetching Prometheus URL..."
prometheus_url=$(wait_for_hostname "prometheus" "kube-prometheus-kube-prome-prometheus")

echo "[*] Fetching Grafana URL and credentials..."
grafana_url=$(wait_for_hostname "prometheus" "kube-prometheus-grafana")
grafana_user="admin"
grafana_password=$(kubectl -n prometheus get secret kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Print results
echo
echo "------------------------"
echo "✅ ArgoCD URL:     http://$argo_url"
echo "   ArgoCD User:    $argo_user"
echo "   ArgoCD Password: $argo_password"
echo
echo "✅ Prometheus URL: http://$prometheus_url:9090"
echo
echo "✅ Grafana URL:    http://$grafana_url"
echo "   Grafana User:   $grafana_user"
echo "   Grafana Password: $grafana_password"
echo "------------------------"
