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

# Prometheus
if kubectl get deployment prometheus-server -n monitoring &> /dev/null; then
    PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app=prometheus -o name | head -1 | sed 's/pod\///')
    if [ -n "$PROMETHEUS_POD" ]; then
        kubectl port-forward pod/$PROMETHEUS_POD -n monitoring 9090:80 &
        echo "Prometheus: http://localhost:9090"
    fi
fi

# Grafana
if kubectl get deployment grafana -n monitoring &> /dev/null; then
    GRAFANA_POD=$(kubectl get pods -n monitoring -l app=grafana -o name | head -1 | sed 's/pod\///')
    if [ -n "$GRAFANA_POD" ]; then
        kubectl port-forward pod/$GRAFANA_POD -n monitoring 3001:80 &
        echo "Grafana: http://localhost:3001"
    fi
fi