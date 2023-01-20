# Set variables (globally unique)
export ACR_NAME="workloadidentitysandbox2acr" # e.g. workloadidentitysandbox2acr (alphanumberic only up to 50 chars)

# Other variables (do not change)
export AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME="workload-identity-sa"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapi
  labels:
    app: weather-forecast
spec:
  replicas: 1
  selector:
    matchLabels:
      service: webapi
  template:
    metadata:
      labels:
        app: weather-forecast
        azure.workload.identity/use: "true"
        service: webapi
    spec:
      serviceAccountName: ${AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME}
      containers:
        - name: webapi
          image: ${ACR_NAME}.azurecr.io/aksworkloadidentitysampleapi:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 80
              protocol: TCP
          env:
            - name: ASPNETCORE_URLS
              value: http://+:80
---
apiVersion: v1
kind: Service
metadata:
  name: webapi
  labels:
    app: weather-forecast
    service: webapi
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  selector:
    service: webapi
EOF