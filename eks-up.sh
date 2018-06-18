CLUSTER_NAME=${CLUSTER_NAME:-henderb}
SUBNETS=${SUBNETS:-subnet-1e841c69,subnet-2c7f0549,subnet-f968d5a0}
MASTERS_SECURITY_GROUP=${SECURITY_GROUP:-sg-a71864d6}
VPC=${VPC:-vpc-ffe58c9a}
SSH_KEYPAIR=${SSH_KEYPAIR:-henderb}

CF_TEMPLATE=https://henderb-cf-templates.s3-us-west-2.amazonaws.com/amazon-eks-nodegroup-core.yaml

export AWS_PROFILE=brian

#############################

set -e
set -x

CLUSTER_STATUS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query cluster.status | tr -d \")
until [ "${CLUSTER_STATUS}" == "ACTIVE" ]; do
    if [ "${CLUSTER_STATUS}" == "CREATING" ]; then
        echo "Waiting for cluster to start..."
        sleep 1m
    else
        echo "Creating cluster."
        aws eks create-cluster \
            --name ${CLUSTER_NAME} \
            --role-arn arn:aws:iam::157842721751:role/aws-eks \
            --resources-vpc-config subnetIds=${SUBNETS},securityGroupIds=${MASTERS_SECURITY_GROUP}

        aws cloudformation create-stack \
            --stack-name ${CLUSTER_NAME}-eks-nodes-core \
            --template-url ${CF_TEMPLATE} \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters \
                ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${MASTERS_SECURITY_GROUP} \
                ParameterKey=ClusterName,ParameterValue=${CLUSTER_NAME} \
                ParameterKey=VpcId,ParameterValue=${VPC}
    fi
    CLUSTER_STATUS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query cluster.status | tr -d \")
done

KUBE_ENDPOINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query cluster.endpoint | tr -d \")
aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --query cluster.certificateAuthority.data \
    | tr -d \" \
    | base64 -d \
    > eks-${CLUSTER_NAME}.ca.crt

kubectl config set-cluster ${CLUSTER_NAME} \
    --server=${KUBE_ENDPOINT} \
    --certificate-authority=eks-${CLUSTER_NAME}.ca.crt

kubectl config set-context ${CLUSTER_NAME} \
    --cluster ${CLUSTER_NAME} \
    --user=aws

kubectl config use-context ${CLUSTER_NAME}

kubectl apply -f eks-node-cm.yaml

