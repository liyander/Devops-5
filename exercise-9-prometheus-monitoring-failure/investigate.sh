#!/bin/bash

echo "=== Exercise 9: Prometheus Monitoring Failure Investigation ==="

echo ""
echo "--- Step 1: Check Prometheus targets ---"
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
sleep 2
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool

echo ""
echo "--- Step 2: Check ServiceMonitor ---"
kubectl get servicemonitor -n monitoring payment-service-monitor -o yaml

echo ""
echo "--- Step 3: Check Service port names ---"
kubectl get svc -n production payment-service -o jsonpath='{.spec.ports[*].name}'
echo ""

echo ""
echo "--- Step 4: Check Prometheus logs ---"
kubectl logs -n monitoring sts/prometheus-server --tail=50

echo ""
echo "--- Step 5: Check Prometheus config ---"
kubectl get configmap -n monitoring prometheus-server -o yaml | grep -A 20 "payment"

echo ""
echo "--- Step 6: Verify endpoint discovery ---"
kubectl get endpoints -n production payment-service

echo ""
echo "--- Step 7: Grafana check ---"
kubectl port-forward -n monitoring svc/grafana 3000:80 &
sleep 2
echo "Check Grafana at http://localhost:3000 -> Dashboards -> Payment Service"

echo ""
echo "--- Root Cause ---"
echo "ServiceMonitor references port name 'metrics' but the Service defines"
echo "the port as 'prometheus'. This name mismatch causes Prometheus to be"
echo "unable to discover the scrape target, resulting in 'payment-service DOWN'"
echo "and 'context deadline exceeded' errors."
echo ""
echo "--- Fix ---"
echo "Rename the service port from 'prometheus' to 'metrics' to match the ServiceMonitor."
echo "kubectl apply -f service-fixed.yaml"
