#!/usr/bin/env bash

###################################################
# Run once immediately after building EKS with CDK.
###################################################

# Update kubeconfig
aws eks update-kubeconfig --region ap-northeast-1 --name eks-cluster --profile akari_mfa

# Install ESO from Helm chart repository
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true

# Install ArgoCD
ns_argocd=`kubectl get ns -o json | jq -r '.items[] | .metadata.name' | grep argocd`
if [ -z "$ns_argocd" ]; then
  kubectl create namespace argocd
  echo -e "Successfully created namespace of argocd."
else
  echo -e "Namespace of argocd already exists."
fi

svc_argocd=`kubectl get svc -n argocd -o json | jq -r '.items[] | .metadata.name' | grep argocd-applicationset-controller`
if [ -z "$svc_argocd" ]; then
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  while [ -z "$svc_argocd" ]; do
    echo -n "."
    sleep 1
    svc_argocd=`kubectl get svc -n argocd -o json | jq -r '.items[] | .metadata.name' | grep argocd-applicationset-controller`
  done
  echo -e "\nSuccessfully applied ArgoCD manifest.\n"
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  echo -e "Successfully changed ArgoCD server to LoadBalancer type.\n"
else
  echo -e "ArgoCD manifest has already been applied.\n"
fi

# Show External IP, Initial User, and Initial Password
external_ip=`kubectl get svc argocd-server -n argocd -o json | jq -r '.status.loadBalancer.ingress[].hostname'`
while [ -z "$external_ip" ]; do
  echo -n "."
  sleep 1
  external_ip=`kubectl get svc argocd-server -n argocd -o json | jq -r '.status.loadBalancer.ingress[].hostname'`
done
echo -e "\n"
initial_user="admin"
initial_password=`kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
while [ -z "$initial_password" ]; do
  echo -n "."
  sleep 1
  initial_password=`kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
done
echo "External IP     : $external_ip"
echo "Initial User    : $initial_user"
echo "Initial Password: $initial_password"
echo -e "\n"

# Wait for ArgoCD to start
accessable_to_argocd=`nslookup -type=ns $external_ip | grep "Authoritative answers can be found from"`
while [ -z "$accessable_to_argocd" ]; do
  echo -n "."
  sleep 1
  accessable_to_argocd=`nslookup -type=ns $external_ip | grep "Authoritative answers can be found from"`
done

# Login to ArgoCD
argocd login "$external_ip" --username admin --password "$initial_password" --insecure

initial_secret=`kubectl get secret/argocd-initial-admin-secret -n argocd -o json | jq -r '.metadata.name'`
if [ -n "$initial_secret" ]; then
  # Update password for admin
  new_password=`openssl rand -base64 6`
  echo "New Password : $new_password"
  argocd account update-password --account admin --current-password "$initial_password" --new-password "$new_password" --insecure

  # Remove the secret resource containing initial password
  kubectl --namespace argocd delete secret/argocd-initial-admin-secret
else
  echo -n "Secret which stored the initial password for ArgoCD does not exist.\n"
fi

# Create application
kubectl apply -f ./application.yaml