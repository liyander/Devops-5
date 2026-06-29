#!/bin/bash

echo "=== Exercise 12: Node Recovery ==="

NODE=$(kubectl get nodes --field-selector=status.conditions.Ready=False -o jsonpath='{.items[0].metadata.name}')
echo "Recovering node: $NODE"

echo ""
echo "--- Step 1: Cordon the node to prevent new pods ---"
kubectl cordon "$NODE"

echo ""
echo "--- Step 2: Clean up old container logs ---"
echo "Removing rotated/old container log files..."
ssh "$NODE" "find /var/log/containers/ -name '*.log' -mtime +1 -delete"
ssh "$NODE" "find /var/log/pods/ -name '*.log' -mtime +1 -delete"

echo ""
echo "--- Step 3: Truncate large active log files ---"
ssh "$NODE" "find /var/log/containers/ -name '*.log' -size +100M -exec truncate -s 0 {} \;"

echo ""
echo "--- Step 4: Clean up unused Docker images ---"
ssh "$NODE" "crictl rmi --prune 2>/dev/null || docker system prune -af 2>/dev/null"

echo ""
echo "--- Step 5: Clean up old kubelet logs ---"
ssh "$NODE" "journalctl --vacuum-size=100M"

echo ""
echo "--- Step 6: Verify disk space recovered ---"
ssh "$NODE" "df -h /var/log"

echo ""
echo "--- Step 7: Uncordon the node ---"
kubectl uncordon "$NODE"

echo ""
echo "--- Step 8: Verify node is Ready ---"
kubectl get node "$NODE" -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'

echo ""
echo "--- Step 9: Prevent future occurrences ---"
echo "Apply log rotation daemonset..."
kubectl apply -f log-cleanup-daemonset.yaml
