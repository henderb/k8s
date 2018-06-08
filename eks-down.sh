CLUSTER_NAME=henderb

export AWS_PROFILE=brian

#############################

aws cloudformation delete-stack \
    --stack-name ${CLUSTER_NAME}-worker-nodes

aws eks delete-cluster \
    --name ${CLUSTER_NAME} \

