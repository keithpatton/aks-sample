# Creates AKS Cluster ensures Azure AD Workload Identity is enabled
# Creates Key Vault and User Managed Identity with appropriate Key Vault Permissions and links this identity to AKS Service Account
# Creates Azure Container Registry and links it to the AKS Cluster
# Creates Storage Classes and Persisent Volume Claims for storage writing test
# Recommended: Use Azure Cloud Shell in bash mode within your Azure subscription
# Note: ensure you have sufficient rights (e.g., owner/contributor role) to create and manage Azure resources.

# Set variables (globally unique)
export ACR_NAME="workloadidentitysandbox2acr" # e.g. workloadidentitysandbox2acr (alphanumberic only up to 50 chars). Important: Set in deploy.sh also
export KEYVAULT_NAME="aks-sandbox3-kv" # e.g. aks-sandbox2-kv (up to 24 url allowable chars)

# Other variables (do not change)
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export RESOURCE_GROUP="sandbox-rg"
export LOCATION="AustraliaEast"
export AKS_NAME="sandbox-aks"
export AKS_NODES_RESOURCE_GROUP="sandbox-aks-nodes-rg"
export AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME="workload-identity-sa"
export AKS_NAMESPACE="default"
export AZ_FEDERATED_IDENTITY_NAME="workload-identity-fed" 
export KEYVAULT_IDENTITY_NAME="kvidentity2"
export STORAGECLASS_ACCOUNT_NAME="azurestorageandbox1"
export STORAGECLASS_BLOB_NAME="azureblob-nfs-standard"
export STORAGECLASS_BLOB_NAME_TENANT1="azureblob-nfs-standard-tenant1"
export STORAGECLASS_BLOB_NAME_TENANT2="azureblob-nfs-standard-tenant2"
export PVCLAIM_BLOB_NAME="azure-blob"
export PVCLAIM_BLOB_NAME_TENANT1="azure-blob-tenant1"
export PVCLAIM_BLOB_NAME_TENANT2="azure-blob-tenant2"

# Ensure providers are registered
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerRegistry 

# Enable Preview feature 'Azure AD Workload Identity' (GA Expected during 2023)
az extension add --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az provider register --namespace Microsoft.ContainerService

# Create resource group 
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"

# Create AKS Cluster and fetch credentials
az aks create -g ${RESOURCE_GROUP} -n ${AKS_NAME} --node-count 1 --enable-oidc-issuer --enable-blob-driver --enable-workload-identity --enable-managed-identity --generate-ssh-keys --node-resource-group ${AKS_NODES_RESOURCE_GROUP}
az aks get-credentials -n ${AKS_NAME} -g "${RESOURCE_GROUP}"

# Create a Key Vault resource (note: key vault names are globally unique, so update number as required)
az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}"

# Create a User Managed Identity for the newly created Key Vault resource:
az identity create --name "${KEYVAULT_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION_ID}"

# Grant the Managed Identity permissions on the Key Vault resource:
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${KEYVAULT_IDENTITY_NAME}" --query 'clientId' -otsv)"
az keyvault set-policy --name "${KEYVAULT_NAME}" --secret-permissions get list set delete --spn "${USER_ASSIGNED_CLIENT_ID}"

# Create an AKS service account linked to the Key Vault assigned Managed Identity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  labels:
    azure.workload.identity/use: "true"
  name: "${AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME}"
  namespace: "${AKS_NAMESPACE}"
EOF

# Create the federated identity credential between the Azure Managed Identity and the AKS Service Account
export OICD_ISSUER_URL="$(az aks show -n "${AKS_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -otsv)"
az identity federated-credential create --name "${AZ_FEDERATED_IDENTITY_NAME}" --identity-name "${KEYVAULT_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${OICD_ISSUER_URL}" --subject system:serviceaccount:"${AKS_NAMESPACE}":"${AKS_WORKLOAD_IDENTITY_SERVICE_ACCOUNT_NAME}"

# Create Azure Container Registry (ACR) to store container images
az acr create --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --sku Basic

# Ensure AKS cluster has rights to pull from the ACR
az aks update -n ${AKS_NAME} -g ${RESOURCE_GROUP} --attach-acr ${ACR_NAME}

# Create Azure Container Registry (ACR) to store container images
az acr create --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --sku Basic

# Create custom StorageClasses which uses the Blob CSI Driver from Microsoft

# common storage class container
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: "${STORAGECLASS_BLOB_NAME}"
  namespace: "${AKS_NAMESPACE}"
provisioner: blob.csi.azure.com
parameters:
  skuName: Standard_ZRS
  containerName: common
  protocol: nfs
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

# tenant1 storage class container
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: "${STORAGECLASS_BLOB_NAME_TENANT1}"
  namespace: "${AKS_NAMESPACE}"
provisioner: blob.csi.azure.com
parameters:
  skuName: Standard_ZRS
  containerName: tenant1
  protocol: nfs
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

# tenant2 storage class container
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: "${STORAGECLASS_BLOB_NAME_TENANT2}"
  namespace: "${AKS_NAMESPACE}"
provisioner: blob.csi.azure.com
parameters:
  skuName: Standard_ZRS
  containerName: tenant2
  protocol: nfs
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

# persistent volume claim for common storage class container
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "${PVCLAIM_BLOB_NAME}"
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: "${STORAGECLASS_BLOB_NAME}"
  resources:
    requests:
      storage: 5Gi
EOF

# persistent volume claim for tenant1 storage class container
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "${PVCLAIM_BLOB_NAME_TENANT1}"
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: "${STORAGECLASS_BLOB_NAME_TENANT1}"
  resources:
    requests:
      storage: 5Gi
EOF

# persistent volume claim for tenant2 storage class container
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "${PVCLAIM_BLOB_NAME_TENANT2}"
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: "${STORAGECLASS_BLOB_NAME_TENANT2}"
  resources:
    requests:
      storage: 5Gi
EOF