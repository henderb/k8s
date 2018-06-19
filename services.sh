kubectl config set-context $(kubectl config current-context) --namespace=kube-system
helm install --name kube2iam stable/kube2iam -f kube2iam/values.yaml

helm install --name nginx-ingress stable/nginx-ingress

helm install --name external-dns stable/external-dns -f external-dns/values.yaml

helm install --name cert-manager stable/cert-manager -f cert-manager/values-staging.yaml
kubectl create -f cert-manager/clusterissuer-staging.yaml
