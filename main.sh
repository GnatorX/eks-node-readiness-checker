#!/bin/bash
# set -euo pipefail
# include the common-used shortcuts

echo $1

waitNode(){
    kubectl wait nodes/"$1" --for condition=Running --timeout=32s
}

waitPodOnNode(){
     kubectl wait pods -A --field-selector spec.nodeName="$1" --for=condition=Ready --timeout=32s
}

getNodeNameByInstanceId(){
    aws ec2 describe-instances --instance-id "$1" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].PrivateDnsName' --output text
}

update_kubeconfig(){
    aws eks update-kubeconfig --name "$1"  --kubeconfig /tmp/kubeconfig
}


detailType=$(echo $1 | jq -r '.["detail-type"] | select(type == "string")')
instanceId=$(echo $1 | jq -r '.detail.EC2InstanceId | select(type == "string")')
autoScalingGroupName=$(echo $1 | jq -r '.detail.AutoScalingGroupName | select(type == "string")')
lifecycleActionToken=$(echo $1 | jq -r '.detail.LifecycleActionToken | select(type == "string")')
lifecycleHookName=$(echo $1 | jq -r '.detail.LifecycleHookName | select(type == "string")')
lifecycleTransition=$(echo $1 | jq -r '.detail.LifecycleTransition | select(type == "string")')

# always update kubeconfig
update_kubeconfig "$cluster_name" 

nodeName=$(getNodeNameByInstanceId $instanceId)

# wait for node to be in Ready state
echo "[INFO] waiting for node to be in Running state"
waitNode "$nodeName"

echo "[INFO] node is in Ready state"

echo "[INFO] waiting for pods on node to be in Running state"
waitPodOnNode "$nodeName"
echo "[INFO] pods on node in Running state"

if [ "$detailType"=="EC2 Instance-launch Lifecycle Action" ]; then
    echo "[INFO] start autoscaling group complete-lifecycle-actiopn callback"
    aws autoscaling complete-lifecycle-action \
    --lifecycle-hook-name $lifecycleHookName \
    --auto-scaling-group-name $autoScalingGroupName \
    --instance-id $instanceId \
    --lifecycle-action-token $lifecycleActionToken \
    --lifecycle-action-result "CONTINUE"
fi

exit 0