#!/usr/bin/env bash

###################################################
# Run once immediately after building EKS with CDK.
###################################################

# Install ESO from Helm chart repository
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Show External IP, Initial User, and Initial Password
external_ip=`kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[].hostname}"`
initial_user="admin"
initial_password=`kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
echo External IP:      $external_ip
echo Initial User:     $initial_user
echo Initial Password: $initial_password

# Login to ArgoCD
expect -c "
    set timeout 10
    spawn argocd login $external_ip
    expect \"WARNING\"
    send \"y\n\"
    expect \"Username\"
    send \"$initial_user\n\"
    expect \"Password\"
    send \"$initial_password\n\"
    exit 0
"
echo "\n"

# Update password for admin
new_password='openssl rand -base64 10'
echo New Password:    $initial_password
expect -c "
    set timeout 10
    spawn argocd account update-password
    expect \"*** Enter password\"
    send \"$initial_password\n\"
    expect \"*** Enter new password\"
    send \"$new_password\n\"
    expect \"*** Confirm new password\"
    send \"$new_password\n\"
    exit 0
"

# Remove the secret resource containing initial password
kubectl --namespace argocd delete secret/argocd-initial-admin-secret

# Create application
kubectl apply -f /Users/akarikeisuke/Documents/private/myk8s/argocd/manifest.yml