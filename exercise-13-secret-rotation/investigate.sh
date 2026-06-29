#!/bin/bash

echo "=== Exercise 13: Secret Rotation Outage Investigation ==="

echo ""
echo "--- Step 1: Check application status ---"
kubectl get pods -n production -l app=payment-service
kubectl logs -n production -l app=payment-service --tail=50

echo ""
echo "--- Step 2: Check the Kubernetes secret ---"
kubectl get secret payment-secret -n production -o yaml
echo ""
echo "Last updated annotation:"
kubectl get secret payment-secret -n production -o jsonpath='{.metadata.annotations.last-updated}'
echo ""

echo ""
echo "--- Step 3: Check AWS Secrets Manager ---"
aws secretsmanager get-secret-value --secret-id production/payment-service/api-token --query 'VersionStages' --output text
echo ""
echo "Current secret value in AWS:"
aws secretsmanager get-secret-value --secret-id production/payment-service/api-token --query 'SecretString' --output text
echo ""

echo ""
echo "--- Step 4: Compare K8s secret vs AWS secret ---"
K8S_TOKEN=$(kubectl get secret payment-secret -n production -o jsonpath='{.data.api-token}' | base64 -d)
AWS_TOKEN=$(aws secretsmanager get-secret-value --secret-id production/payment-service/api-token --query 'SecretString' --output text)
echo "K8s token: $K8S_TOKEN"
echo "AWS token: $AWS_TOKEN"
if [ "$K8S_TOKEN" = "$AWS_TOKEN" ]; then
  echo "MATCH: Secrets are in sync"
else
  echo "MISMATCH: K8s secret is stale!"
fi

echo ""
echo "--- Step 5: Check External Secrets Operator ---"
kubectl get externalsecret -n production -o yaml
kubectl logs -n external-secrets deployment/external-secrets-controller --tail=50

echo ""
echo "--- Step 6: Check if reloader is installed ---"
kubectl get deployment -n production -l app.kubernetes.io/name=reloader

echo ""
echo "--- Step 7: Check pod env vars (currently mounted) ---"
kubectl exec -n production deploy/payment-service -- printenv API_TOKEN

echo ""
echo "--- Root Cause ---"
echo "AWS Secrets Manager rotated the secret, but the Kubernetes Secret was NOT updated."
echo ""
echo "Reasons the rotation did not propagate:"
echo ""
echo "1. No External Secrets Operator (ESO) is configured to sync AWS Secrets Manager"
echo "   with Kubernetes Secrets. The K8s secret was created manually and is static."
echo ""
echo "2. Even if the K8s secret were updated manually, pods would NOT pick up the new"
echo "   value because Kubernetes does not update environment variables in running pods"
echo "   when secrets change. Pods must be restarted to read new secret values."
echo ""
echo "3. Without a tool like Stakater Reloader or a rollout restart, the deployment"
echo "   continues using the old secret values that were injected at pod creation time."
echo ""
echo "--- Fix ---"
echo "1. Update the K8s secret with the new rotated values"
echo "   kubectl apply -f secret-rotated.yaml"
echo ""
echo "2. Restart pods to pick up new secret values"
echo "   kubectl rollout restart deployment/payment-service -n production"
echo ""
echo "3. Long-term: Deploy External Secrets Operator to auto-sync from AWS Secrets Manager"
echo "   kubectl apply -f cluster-secret-store.yaml"
echo "   kubectl apply -f external-secret.yaml"
echo ""
echo "4. Add Stakater Reloader annotation to auto-restart pods on secret changes"
echo "   (Already included in deployment.yaml)"
