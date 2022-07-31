#!/usr/bin/env bash

###################################################
# Run once immediately after building EKS with CDK.
###################################################

# Update kubeconfig
aws eks update-kubeconfig --region ap-northeast-1 --name eks-cluster --profile akari_mfa
echo -e "\n"

# Install ESO from Helm chart repository
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true
echo -e "\n"

# Install ArgoCD
ns_argocd=`kubectl get ns -o json | jq -r '.items[] | .metadata.name' | grep argocd`
if [ -z "$ns_argocd" ]; then
  kubectl create namespace argocd
else
  echo -e "Namespace of argocd already exists\n"
fi

svc_argocd=`kubectl get svc -n argocd -o json | jq -r '.items[] | .metadata.name' | grep argocd-applicationset-controller`
if [ -z "$svc_argocd" ]; then
  echo -e "Start to apply ArgoCD manifest.\n"
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
  echo -e "\nApplying ArgoCD manifest"
  count=0
  while [ -z "$svc_argocd" ]; do
    count=`expr $count + 1`
    if [ $count -gt 10 ]; then
      echo -e "Timeout to apply ArgoCD manifest\n"
      break
    fi

    echo -n "."
    sleep 1
    svc_argocd=`kubectl get svc -n argocd -o json | jq -r '.items[] | .metadata.name' | grep argocd-applicationset-controller`
  done
  echo -e "\nSuccessfully applied ArgoCD manifest\n"
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  echo -e "Successfully changed ArgoCD server to LoadBalancer type\n"
else
  echo -e "ArgoCD manifest has already been applied\n"
fi

# Get External IP
external_ip=`kubectl get svc argocd-server -n argocd -o json 2>/dev/null | jq -r '.status.loadBalancer.ingress[].hostname' 2>/dev/null`
if [[ -z $external_ip ]]; then
  echo -e "\nWaiting to start argocd-server"
  count=0
  while [[ -z $external_ip ]]; do
    count=`expr $count + 1`
    if [ $count -gt 10 ]; then
      echo -e "Timeout to start up argocd-server"
      break
    fi

    echo -n "."
    sleep 1
    external_ip=`kubectl get svc argocd-server -n argocd -o json 2>/dev/null | jq -r '.status.loadBalancer.ingress[].hostname' 2>/dev/null`
  done
fi
echo -e "\n"

# Get Initial User
initial_user="admin"

# Get Initial Password
initial_password=`kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d; echo`
if [[ -z $initial_password ]]; then
  echo -e "\nWaiting to start secret/argocd-initial-admin-secret"
  count=0
  while [[ -z $initial_password ]]; do
    count=`expr $count + 1`
    if [ $count -gt 20 ]; then
      echo -e "Timeout to start up secret/argocd-initial-admin-secret"
      break
    fi

    echo -n "."
    sleep 1
    initial_password=`kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d; echo`
  done
fi

# Login to ArgoCD
if [ -n "$initial_password" ]; then
  echo -e "\nLogin to Argo CD" 
  accessable_to_argocd=`nslookup -type=ns $external_ip | grep "Authoritative answers can be found from"`
  count=0
  while [ -z "$accessable_to_argocd" ]; do
    count=`expr $count + 1`
    if [ $count -gt 90 ]; then
      echo -e "Timeout to login to Argo CD"
      break
    fi

    echo -n "."
    sleep 1
    accessable_to_argocd=`nslookup -type=ns $external_ip | grep "Authoritative answers can be found from"`
  done
  argocd login "$external_ip" --username admin --password "$initial_password" --insecure

  # Update password for admin
  new_password=`openssl rand -base64 6`
  echo -e "\nChange your login password to $new_password"
  argocd account update-password --account admin --current-password "$initial_password" --new-password "$new_password" --insecure
  echo -e "\n"

  # Remove the secret resource containing initial password
  kubectl --namespace argocd delete secret/argocd-initial-admin-secret
  echo -e "\n"
fi

echo "*********************************************************************************************"
echo "External IP      : $external_ip"
echo "Initial User     : $initial_user"
echo "Initial Password : $initial_password"
echo "New Password     : $new_password"
echo "*********************************************************************************************"
echo -e "\n"

# Deploy application
kubectl apply -f ./manifests/overlays/production/production.yaml