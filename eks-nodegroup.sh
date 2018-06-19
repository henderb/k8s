CLUSTER_NAME=${CLUSTER_NAME:-henderb}
SECURITY_GROUP=${SECURITY_GROUP:-sg-a71864d6}
VPC=${VPC:-vpc-ffe58c9a}
SSH_KEYPAIR=${SSH_KEYPAIR:-henderb2}

SUBNETS="subnet-1e841c69 subnet-2c7f0549 subnet-f968d5a0"
NODE_SIZES="m5.large c5.large r4.large"

CF_TEMPLATE=https://henderb-cf-templates.s3-us-west-2.amazonaws.com/amazon-eks-nodegroup-per-group.yaml
NODE_AMI=ami-73a6e20b

NODE_INSTANCE_PROFILE="arn:aws:iam::157842721751:instance-profile/henderb-eks-nodes-core-NodeInstanceProfile-YJJTLVDD2TJ7"
NODE_INSTANCE_ROLE="arn:aws:iam::157842721751:role/henderb-eks-nodes"
NODE_SECURITY_GROUP="sg-7aa38e0b"

export AWS_PROFILE=brian

#############################

set -e
#set -x

for SUBNET in $SUBNETS; do
    for NODE_SIZE in $NODE_SIZES; do
        NODE_SIZE_NAME=$(echo ${NODE_SIZE} | sed 's/\./-/')
        aws cloudformation create-stack \
            --stack-name ${CLUSTER_NAME}-${SUBNET}-${NODE_SIZE_NAME}-nodes \
            --template-url ${CF_TEMPLATE} \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters \
                ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${SECURITY_GROUP} \
                ParameterKey=ClusterName,ParameterValue=${CLUSTER_NAME} \
                ParameterKey=KeyName,ParameterValue=${SSH_KEYPAIR} \
                ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=0 \
                ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=0 \
                ParameterKey=NodeGroupName,ParameterValue=${CLUSTER_NAME}-${SUBNET}-${NODE_SIZE_NAME}-nodes \
                ParameterKey=NodeImageId,ParameterValue=${NODE_AMI} \
                ParameterKey=NodeInstanceType,ParameterValue=${NODE_SIZE} \
                ParameterKey=NodeInstanceProfile,ParameterValue=${NODE_INSTANCE_PROFILE} \
                ParameterKey=NodeSecurityGroup,ParameterValue=${NODE_SECURITY_GROUP} \
                ParameterKey=VpcId,ParameterValue=${VPC} \
                ParameterKey=Subnets,ParameterValue=${SUBNET}
    done
done

