#!/bin/bash

echo "=== Exercise 7: ALB Ingress Failure Investigation ==="

echo ""
echo "--- Step 1: Check Ingress status ---"
kubectl get ingress -n production payment-service-ingress -o yaml

echo ""
echo "--- Step 2: Check Ingress events ---"
kubectl describe ingress payment-service-ingress -n production

echo ""
echo "--- Step 3: Check ALB Controller logs ---"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100

echo ""
echo "--- Step 4: Verify subnet tags ---"
aws ec2 describe-subnets --query 'Subnets[*].{SubnetId:SubnetId,Tags:Tags}' --output table

echo ""
echo "--- Step 5: Check if subnets have correct ELB tags ---"
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1" --query 'Subnets[*].SubnetId'

echo ""
echo "--- Step 6: Verify ALB Controller IAM permissions ---"
aws iam list-attached-role-policies --role-name AmazonEKSLoadBalancerControllerRole

echo ""
echo "--- Step 7: Check target group health ---"
aws elbv2 describe-target-groups --query 'TargetGroups[*].{ARN:TargetGroupArn,Name:TargetGroupName}'

echo ""
echo "--- Step 8: Describe services ---"
kubectl get svc -n production payment-service -o yaml

echo ""
echo "--- Root Cause ---"
echo "The ALB controller cannot discover subnets because the subnet IDs in the"
echo "ingress annotation are invalid or the subnets lack required Kubernetes tags."
echo ""
echo "Required tags on subnets:"
echo "  kubernetes.io/cluster/<cluster-name> = owned|shared"
echo "  kubernetes.io/role/elb = 1 (for public subnets)"
echo ""
echo "--- Fix ---"
echo "1. Update ingress annotation with valid subnet IDs"
echo "2. Tag subnets correctly for ALB discovery"
echo "3. Apply the fixed ingress: kubectl apply -f ingress-fixed.yaml"
