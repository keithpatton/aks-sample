# Set variables (globally unique)
export ACR_NAME="workloadidentitysandbox2acr" # e.g. workloadidentitysandbox2acr (alphanumberic only up to 50 chars)

# Other variables (do not change)
export AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME="workload-identity-sa"
export PVCLAIM_BLOB_NAME="azure-blob"
export PVCLAIM_BLOB_NAME_TENANT1="azure-blob-tenant1"
export PVCLAIM_BLOB_NAME_TENANT2="azure-blob-tenant2"

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
          volumeMounts:
            - mountPath: "/var/common"
              name: common
            - mountPath: "/var/tenant1"
              name: tenant1
            - mountPath: "/var/tenant2"
              name: tenant2
      volumes:
         - name: common
           persistentVolumeClaim:
             claimName: ${PVCLAIM_BLOB_NAME}
         - name: tenant1
           persistentVolumeClaim:
             claimName: ${PVCLAIM_BLOB_NAME_TENANT1}
         - name: tenant2
           persistentVolumeClaim:
             claimName: ${PVCLAIM_BLOB_NAME_TENANT2}
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