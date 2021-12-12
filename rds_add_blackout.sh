#!/bin/bash
#==============================================================================
# FILE: rds_add_blackout.sh
#
# USAGE: rds_add_blackout.sh $AWSPROFILE $DBINSTANCE
#
# DESCRIPTION: Script to add a blackout by addng a tag to the RDS instance
#              which will stop lambda functions erroring
#
# AUTHOR: Jade Buckingham
#
# CREATED: 11/11/2020
#
# VERSION: 1.0
#
# AMENDMENT LOG:
# DATE BY DETAILS
# ----------- ---------------- ------------------------------------------------
# 11/11/2020  Jade Buckingham  Initial script
#==============================================================================

export AWSPROFILE=$1
export DBINSTANCE=$2

# Check variables have been passed through
if [ $# -lt 2 ]; then
    echo "Not enough variables entered... Please specify aws profile and db instance"
    exit 1
fi

echo "##################################################"
echo "Script started at $(date)"
echo "##################################################"

# Grab arn for db instance
arn=$(aws rds describe-db-instances \
    --db-instance-identifier $DBINSTANCE \
    --output text --query 'DBInstances[*].DBInstanceArn' \
    --profile $AWSPROFILE)

echo -e "\nAdding blackout for $DBINSTANCE in $AWSPROFILE account"

# Add tag to db instance
aws rds add-tags-to-resource \
    --resource-name $arn \
    --tags "[{\"Key\": \"Monitoring\",\"Value\": \"nomon\"}]" \
    --profile $AWSPROFILE

# Check tag has been added
tag=$(aws rds list-tags-for-resource \
    --resource-name $arn \
    --profile $AWSPROFILE | grep nomon | wc -l)

if [[ $tag -gt 0 ]]; then
    echo -e "\nBlackout has been added for $DBINSTANCE"
else
    echo -e "\nBlackout does not exist for $DBINSTANCE"
    exit 1;
fi    

echo ""
echo "##################################################"
echo "Script finished at $(date)"
echo "##################################################"
