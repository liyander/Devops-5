#!/bin/bash

echo "=== Exercise 8: Egress Restriction Investigation ==="

echo ""
echo "--- Step 1: Reproduce the issue ---"
kubectl exec -it -n production deploy/payment-service -- curl -v --connect-timeout 5 https://dynamodb.ap-south-1.amazonaws.com

echo ""
echo "--- Step 2: Check Network Policies ---"
kubectl get networkpolicy -n production -o yaml

echo ""
echo "--- Step 3: Check Security Groups on nodes ---"
INSTANCE_ID=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | awk -F'/' '{print $NF}')
SG_IDS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text)
echo "Security Groups: $SG_IDS"
aws ec2 describe-security-groups --group-ids $SG_IDS --query 'SecurityGroups[*].IpPermissionsEgress'

echo ""
echo "--- Step 4: Check Route Tables ---"
SUBNET_ID=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | awk -F'/' '{print $NF}' | xargs -I{} aws ec2 describe-instances --instance-ids {} --query 'Reservations[0].Instances[0].SubnetId' --output text)
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID" --query 'RouteTables[*].Routes'

echo ""
echo "--- Step 5: Check VPC Endpoints ---"
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=com.amazonaws.ap-south-1.dynamodb"

echo ""
echo "--- Step 6: Check DNS resolution ---"
kubectl exec -it -n production deploy/payment-service -- nslookup dynamodb.ap-south-1.amazonaws.com

echo ""
echo "--- Root Causes ---"
echo "1. Security Group egress rules restrict outbound to VPC CIDR only (no 0.0.0.0/0)"
echo "2. Network Policy limits egress to in-cluster traffic only"
echo "3. Route table missing NAT Gateway route for private subnets"
echo "4. No VPC Gateway Endpoint for DynamoDB"
echo ""
echo "--- Fix ---"
echo "1. Add HTTPS egress rule (0.0.0.0/0:443) to Security Group"
echo "2. Update Network Policy to allow egress to AWS API endpoints"
echo "3. Add NAT Gateway route to private route table"
echo "4. Create DynamoDB VPC Gateway Endpoint"
