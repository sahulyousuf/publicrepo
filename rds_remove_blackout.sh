#!/bin/bash
#=====================================================================================
# FILE: rds_remove_blackout.sh
#
# USAGE: rds_remove_blackout.sh $AWSPROFILE $DBINSTANCE
#
# DESCRIPTION: Script to remove a blackout by removing a tag from the RDS instance
#              which will allow lambda functions to query the instance
#
# AUTHOR: Jade Buckingham
#
# CREATED: 11/11/2020
#
# VERSION: 1.0
#
# AMENDMENT LOG:
# DATE BY DETAILS
# ----------- ---------------- -------------------------------------------------------
# 11/11/2020  Jade Buckingham  Initial script
#=====================================================================================

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

echo -e "\nRemoving blackout for $DBINSTANCE in $AWSPROFILE account"

# Add tag to db instance
aws rds remove-tags-from-resource \
    --resource-name $arn \
    --tag-keys Monitoring \
    --profile $AWSPROFILE

# Check tag has been removed
tag=$(aws rds list-tags-for-resource \
    --resource-name $arn \
    --profile $AWSPROFILE | grep nomon | wc -l)

if [[ $tag -eq 0 ]]; then
    echo -e "\nBlackout has been removed for $DBINSTANCE"
else
    echo -e "\nBlackout still exists for $DBINSTANCE"
fi

echo ""
echo "##################################################"
echo "Script finished at $(date)"
echo "##################################################"
