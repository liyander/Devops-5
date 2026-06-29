#!/bin/bash

echo "=== Exercise 12: Node NotReady Investigation ==="

echo ""
echo "--- Step 1: Check node status ---"
kubectl get nodes -o wide

echo ""
echo "--- Step 2: Describe the NotReady node ---"
NODE=$(kubectl get nodes --field-selector=status.conditions.Ready=False -o jsonpath='{.items[0].metadata.name}')
echo "Affected node: $NODE"
kubectl describe node "$NODE"

echo ""
echo "--- Step 3: Check node conditions ---"
kubectl get node "$NODE" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'

echo ""
echo "--- Step 4: Check disk usage ---"
echo "SSH into the node and run:"
echo "  df -h"
echo "  du -sh /var/log/containers/*"
echo "  du -sh /var/lib/docker/*"
echo "  du -sh /var/lib/kubelet/*"

echo ""
echo "--- Step 5: Check large log files ---"
kubectl get node "$NODE" -o jsonpath='{.metadata.name}' | xargs -I{} ssh {} "du -sh /var/log/containers/* | sort -rh | head -20"

echo ""
echo "--- Step 6: Check kubelet logs ---"
kubectl get node "$NODE" -o jsonpath='{.metadata.name}' | xargs -I{} ssh {} "journalctl -u kubelet --no-pager -n 100"

echo ""
echo "--- Diagnosis ---"
echo "Node condition: DiskPressure=True"
echo "Root cause: Container logs consumed 95GB in /var/log/containers/"
echo "This triggered DiskPressure, causing kubelet to evict pods and mark node NotReady."
