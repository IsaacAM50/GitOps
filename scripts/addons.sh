# Instalar controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Crear SealedSecret
kubectl create secret generic app-secrets \
  --namespace=gitops-app \
  --from-literal=circleci-token='TU_TOKEN' \
  --dry-run=client -o yaml \
  | kubeseal --format yaml > kubernetes/sealed-secret.yaml

brew install kubeseal

kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system > public-key.pem