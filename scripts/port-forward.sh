kubectl --namespace monitoring port-forward svc/prometheus-server 9090:80 &
kubectl --namespace monitoring port-forward svc/grafana 3001:80 &

# Backend
if kubectl get deployment gitops-backend -n gitops-app &> /dev/null; then
    BACKEND_POD=$(kubectl get pods -n gitops-app -l app=gitops-backend -o name | head -1 | sed 's/pod\///')
    if [ -n "$BACKEND_POD" ]; then
        kubectl port-forward pod/$BACKEND_POD -n gitops-app 8000:8000 &
        echo "Backend: http://localhost:8000"
    fi
fi

# Frontend
if kubectl get deployment gitops-frontend -n gitops-app &> /dev/null; then
    FRONTEND_POD=$(kubectl get pods -n gitops-app -l app=gitops-frontend -o name | head -1 | sed 's/pod\///')
    if [ -n "$FRONTEND_POD" ]; then
        kubectl port-forward pod/$FRONTEND_POD -n gitops-app 3000:4173 &
        echo "Frontend: http://localhost:3000"
    fi
fi

