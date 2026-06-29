#!/bin/bash

echo "=== Exercise 10: Loki Logging Failure Investigation ==="

echo ""
echo "--- Step 1: Check Alloy pod status ---"
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy

echo ""
echo "--- Step 2: Check Alloy logs ---"
kubectl logs -n monitoring deployment/alloy --tail=100

echo ""
echo "--- Step 3: Check Loki pod status ---"
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

echo ""
echo "--- Step 4: Check Loki logs ---"
kubectl logs -n monitoring statefulset/loki --tail=100

echo ""
echo "--- Step 5: Verify Alloy config ---"
kubectl get configmap -n monitoring alloy-config -o yaml

echo ""
echo "--- Step 6: Test Loki connectivity from Alloy ---"
kubectl exec -n monitoring deployment/alloy -- curl -v http://loki.monitoring.svc.cluster.local:3100/ready

echo ""
echo "--- Step 7: Test Loki auth ---"
kubectl exec -n monitoring deployment/alloy -- curl -v -H "X-Scope-OrgID: production" http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels

echo ""
echo "--- Step 8: Check Loki auth config ---"
kubectl get configmap -n monitoring loki-config -o yaml | grep auth_enabled

echo ""
echo "--- Step 9: Check Grafana datasource ---"
kubectl get configmap -n monitoring grafana-datasources -o yaml

echo ""
echo "--- Log Flow Trace ---"
echo "Application (stdout/stderr)"
echo "  -> /var/log/containers/*.log"
echo "    -> Alloy (loki.source.file)"
echo "      -> Loki (loki.write) --- FAILURE POINT: HTTP 403"
echo "        -> Grafana (no data)"
echo ""
echo "--- Root Cause ---"
echo "Alloy is configured with a hardcoded password for Loki authentication."
echo "The password has been rotated/changed in Loki but Alloy still uses the old credentials."
echo "This causes HTTP 403 'authentication failed' errors."
echo ""
echo "--- Fix ---"
echo "1. Update Alloy config to use password_file or updated credentials"
echo "2. Restart Alloy to pick up new config"
echo "kubectl apply -f alloy-config-fixed.yaml"
echo "kubectl rollout restart deployment/alloy -n monitoring"
