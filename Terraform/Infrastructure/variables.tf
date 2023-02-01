variable "rg_name" {
  type        = string
  description = "The name of the resource group to be used to provision core Azure resources."
}

variable "acr_name" { 
  description = "The name of the Azure Container Registry instance."
  type        = string
}

variable "aks_name" { 
  description = "The name of the AKS instance."
  type        = string
}

variable "aks_workload_identity_name" { 
  description = "The name of the AKS workload identity."
  type        = string
}

variable "aks_federated_identity_name" { 
  description = "The name of the AKS federated identity."
  type        = string
}

variable "aks_namespace" { 
  description = "The default namespace to be set on AKS."
  type        = string
}

variable "aks_workload_identity_service_account_name" { 
  description = "The name of the service account to use on AKS."
  type        = string
}

variable "aks_vm_size" {
  description = "Kubernetes VM size."
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes to deploy for Kubernetes"
  type        = number
}

variable "kv_name" { 
  description = "The name of the Key Vault instance."
  type        = string
}