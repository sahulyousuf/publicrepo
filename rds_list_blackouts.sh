#!/bin/bash
#==================================================================================================
# FILE: rds_list_blackouts.sh
#
# USAGE: rds_list_blackouts.sh $ELASTICUSERNAME $ELASTICPASSWORD $AWSPROFILE
#
# DESCRIPTION: Script to list all instances with a tag called Monitoring that has a value of nomon
#              Results are sent to daily checks dashboard
#
# AUTHOR: Jade Buckingham
#
# CREATED: 11/11/2020
#
# VERSION: 1.1
#
# AMENDMENT LOG:
# DATE BY DETAILS
# ----------- ---------------- --------------------------------------------------------------------
# 11/11/2020  Jade Buckingham  Initial script
# 05/01/2021  Jade Buckingham  Added check for blackout variable
#==================================================================================================

export SSM_PROFILE=$1 # services-prod or services-non-prod
export AWSPROFILE=$2
export ELASTICUSERNAME=dba_logstash
export ELASTICPASSWORD=$(aws ssm get-parameter --name "/dba/es/$ELASTICUSERNAME" --profile $SSM_PROFILE --with-decryption --output text --query Parameter.Value)
export date=$(date -u +%a""%d""%b""%y"-"%H%M%S)
export date2=$(date -u +%Y.%m)

# Check variables have been passed through
if [ $# -lt 2 ]; then
    echo "Not enough variables entered... Please specify SSM profile e.g. hummingbird-prod and aws profile"
    exit 1
fi

echo "##################################################"
echo "Script started at $(date)"
echo "##################################################"

# Check if password was collected from ssm
if [[ -z "$ELASTICPASSWORD" ]]; then
	echo "Password variable for $ELASTICUSERNAME is empty. Exiting"
	exit 1
fi

# Set elastic env based on aws profile
if [[ $AWSPROFILE == *"non-prod" ]] || [[ $AWSPROFILE == *"dev"* ]]; then
    export ELASTICENV="uat"
elif [[ $AWSPROFILE == *"prod" ]]; then
    export ELASTICENV="prod"
else
    echo -e "\n=>Cannot detect environment running on. Exiting\n" | tee -a $LOG
    exit 1
fi

# List db instances by DBInstanceIdentifier and DBInstanceArn
db_instances_arn=$(aws rds describe-db-instances \
    --profile $AWSPROFILE --output text \
    --query 'DBInstances[?DBInstanceStatus==`available` || DBInstanceStatus==`backing-up` || DBInstanceStatus==`storage-optimization` || DBInstanceStatus==`resetting-master-credentials` ].[DBInstanceArn]' \
    --filters Name=engine,Values=oracle-se1,oracle-se2,oracle-ee,postgres | grep -v nomon)

echo -e "\nChecking for blackouts in $AWSPROFILE"

while IFS= read -r line; do
    # Check if db instances has nomon tag
    tag=$(aws rds list-tags-for-resource \
        --resource-name $line \
        --profile $AWSPROFILE | grep nomon | wc -l)
    # List any db instances with nomon tag
    if [[ $tag -gt 0 ]]; then
        db_instance=$(echo $line | cut -d ':' -f 7)
        db_blackout=1
        echo -e "\nBlackout found for $db_instance"
        JSON_PAYLOAD='{
"date": "'$date'",
"db_instance": "'${db_instance}'",
"db_blackout": "'${db_blackout}'" }'
        echo -e "\nPushing blackout metrics for $db_instance to ES"
        curl -sS -u $ELASTICUSERNAME:$ELASTICPASSWORD -X POST "https://hb-cdlshared-monitoring-rest.$ELASTICENV.cdlcloud.co.uk:9200/$ELASTICENV-dba-sql-metrics-$date2/_doc/" -H 'Content-Type: application/json' --data "$JSON_PAYLOAD"
        echo ""
    else
        # do nothing as no blackout has been found
        :
    fi
done <<<"$db_instances_arn"

echo ""
echo "##################################################"
echo "Script finished at $(date)"
echo "##################################################"
