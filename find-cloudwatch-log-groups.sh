#!/bin/bash
# Bash Script to Find CloudWatch Log Groups Across All Regions

# Get all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

echo "Scanning all regions for CloudWatch Log Groups..."

for region in $regions; do
    echo "Checking region: $region"
    logs=$(aws logs describe-log-groups --region "$region" --query "logGroups[*].logGroupName" --output text)
    if [ ! -z "$logs" ]; then
        echo "✅ Found log groups in region: $region"
        echo "$logs"
        echo "-------------------------------------"
    fi
done
