export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

export NAME=k1.henderb.net
export KOPS_STATE_STORE=s3://henderb-net-kops-state-store

kops create cluster \
    --networking amazon-vpc-routed-eni \
    --zones us-west-2a \
    --master-size t2.small \
    --node-size t2.large \
    ${NAME}

kops update cluster ${NAME} --yes
