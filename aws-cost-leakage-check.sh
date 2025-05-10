#!/bin/bash

echo "🔍 Starting AWS Cost Leakage Check..."

# Get all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

for region in $regions; do
    echo -e "\n🌍 Scanning region: $region"
    
    # EC2 Instances
    ec2=$(aws ec2 describe-instances --region "$region" --query "Reservations[*].Instances[*].State.Name" --output text)
    if echo "$ec2" | grep -q "running"; then
        echo "💡 EC2 instances are running in $region"
    fi

    # EBS Volumes (unattached)
    ebs=$(aws ec2 describe-volumes --region "$region" --query "Volumes[?State=='available'].VolumeId" --output text)
    if [ -n "$ebs" ]; then
        echo "💡 Unattached EBS Volumes in $region: $ebs"
    fi

    # Elastic IPs (unattached)
    eips=$(aws ec2 describe-addresses --region "$region" --query "Addresses[?AssociationId==null].PublicIp" --output text)
    if [ -n "$eips" ]; then
        echo "💡 Unattached Elastic IPs in $region: $eips"
    fi

    # NAT Gateways
    nats=$(aws ec2 describe-nat-gateways --region "$region" --query "NatGateways[?State=='available'].NatGatewayId" --output text)
    if [ -n "$nats" ]; then
        echo "💡 NAT Gateways running in $region: $nats"
    fi

    # RDS Instances
    rds=$(aws rds describe-db-instances --region "$region" --query "DBInstances[*].DBInstanceIdentifier" --output text 2>/dev/null)
    if [ -n "$rds" ]; then
        echo "💡 RDS Instances running in $region: $rds"
    fi

    # Load Balancers
    elbs=$(aws elbv2 describe-load-balancers --region "$region" --query "LoadBalancers[*].LoadBalancerName" --output text 2>/dev/null)
    if [ -n "$elbs" ]; then
        echo "💡 Load Balancers in $region: $elbs"
    fi

    # CloudWatch Logs with no retention set
    logs=$(aws logs describe-log-groups --region "$region" --query "logGroups[?retentionInDays==null].logGroupName" --output text 2>/dev/null)
    if [ -n "$logs" ]; then
        echo "💡 CloudWatch log groups with no retention in $region: $logs"
    fi
done

# S3 check (global service, but region-aware)
echo -e "\n🌍 Scanning S3 buckets..."
buckets=$(aws s3api list-buckets --query "Buckets[*].Name" --output text)
for bucket in $buckets; do
    region=$(aws s3api get-bucket-location --bucket "$bucket" --output text)
    if [[ "$region" == "None" ]]; then region="us-east-1"; fi
    size=$(aws s3api list-objects --bucket "$bucket" --output json --query "[sum(Contents[].Size)]" 2>/dev/null | jq '.[0]')
    if [[ "$size" -gt 1000000000 ]]; then
        echo "💡 Large S3 bucket ($bucket) in $region > 1GB"
    fi
done
