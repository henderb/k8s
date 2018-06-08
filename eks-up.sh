CLUSTER_NAME=${CLUSTER_NAME:-henderb}
SUBNETS=${SUBNETS:-subnet-1e841c69,subnet-2c7f0549,subnet-f968d5a0}
SECURITY_GROUP=${SECURITY_GROUP:-sg-0a87eb7b}
VPC=${VPC:-vpc-ffe58c9a}
SSH_KEYPAIR=${SSH_KEYPAIR:-henderb}

export AWS_PROFILE=brian

#############################

set -e
#set -x

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
            --resources-vpc-config subnetIds=${SUBNETS},securityGroupIds=${SECURITY_GROUP}

        aws cloudformation create-stack \
            --stack-name ${CLUSTER_NAME}-worker-nodes \
            --template-url https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml \
            --capabilities CAPABILITY_IAM \
            --parameters \
                ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${SECURITY_GROUP} \
                ParameterKey=ClusterName,ParameterValue=${CLUSTER_NAME} \
                ParameterKey=KeyName,ParameterValue=${SSH_KEYPAIR} \
                ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=3 \
                ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=1 \
                ParameterKey=NodeGroupName,ParameterValue=${CLUSTER_NAME}-worker-nodes \
                ParameterKey=NodeImageId,ParameterValue=ami-73a6e20b \
                ParameterKey=NodeInstanceType,ParameterValue=t2.medium \
                ParameterKey=VpcId,ParameterValue=${VPC} \
                ParameterKey=Subnets,ParameterValue=\"${SUBNETS}\"
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

NODE_INSTANCE_ROLE=$(aws cloudformation describe-stacks --stack-name ${CLUSTER_NAME}-worker-nodes --query 'Stacks[0].Outputs[?OutputKey==`NodeInstanceRole`].OutputValue' --output text)
cat >eks-node-cm.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${NODE_INSTANCE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
kubectl apply -f eks-node-cm.yaml

