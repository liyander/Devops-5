#!/bin/bash

echo "=== Exercise 11: CrashLoopBackOff Investigation ==="

echo ""
echo "--- Step 1: Check pod status ---"
kubectl get pods -n production -l app=payment-service

echo ""
echo "--- Step 2: Check pod events ---"
kubectl describe pod -n production -l app=payment-service

echo ""
echo "--- Step 3: Check pod logs (current) ---"
kubectl logs -n production -l app=payment-service --tail=50

echo ""
echo "--- Step 4: Check pod logs (previous crash) ---"
kubectl logs -n production -l app=payment-service --previous --tail=50

echo ""
echo "--- Step 5: Is it a DNS issue? ---"
echo "Testing DNS resolution for DB host..."
kubectl run dns-test --image=busybox --restart=Never -n production --rm -it -- nslookup payment-db.production.svc.cluster.local

echo ""
echo "--- Step 6: Is it a database issue? ---"
echo "Checking DB service..."
kubectl get svc -n production payment-db
echo "Checking DB endpoints..."
kubectl get endpoints -n production payment-db
echo "Checking DB pods..."
kubectl get pods -n production -l app=payment-db

echo ""
echo "--- Step 7: Is it a secret issue? ---"
echo "Checking secrets..."
kubectl get secret -n production payment-db-secret -o yaml
echo "Decoding secret values..."
kubectl get secret -n production payment-db-secret -o jsonpath='{.data.username}' | base64 -d
echo ""
kubectl get secret -n production payment-db-secret -o jsonpath='{.data.password}' | base64 -d
echo ""

echo ""
echo "--- Step 8: Test DB connectivity ---"
kubectl run db-test --image=postgres:16 --restart=Never -n production --rm -it -- env PGPASSWORD=$(kubectl get secret payment-db-secret -n production -o jsonpath='{.data.password}' | base64 -d) psql -h 10.20.0.15 -U payment_user -d payments -c "SELECT 1"

echo ""
echo "--- Step 9: Check DB_HOST env var ---"
kubectl get deploy -n production payment-service -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_HOST")].value}'
echo ""

echo ""
echo "--- Diagnosis ---"
echo "The error 'dial tcp 10.20.0.15:5432 connection refused' indicates:"
echo ""
echo "1. DNS issue? NO - The app uses a hardcoded IP (10.20.0.15), not a DNS name."
echo "   The IP may be stale if the database was recreated with a new IP."
echo ""
echo "2. Database issue? YES - The hardcoded IP 10.20.0.15 is no longer valid."
echo "   The database Pod/Service may have been rescheduled to a new IP."
echo "   Connection refused means nothing is listening at that IP:port."
echo ""
echo "3. Secret issue? POSSIBLY - Verify the secret credentials are still valid."
echo "   If the DB password was rotated, this would also cause connection failure."
echo ""
echo "--- Fix ---"
echo "1. Change DB_HOST from hardcoded IP to Kubernetes service DNS name"
echo "2. Verify DB service is running and endpoints are populated"
echo "3. Verify secret credentials match the database"
echo "kubectl apply -f secret-fixed.yaml"
echo "kubectl apply -f deployment-fixed.yaml"
