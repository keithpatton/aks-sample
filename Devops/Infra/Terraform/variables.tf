variable "tenants" {
  type = list(string)
  description = "Tenant List"
  default = "#{tenantsJson}#"
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group to be used to provision core Azure resources."
  default = "#{rgName}#"
}

variable "rg_aks_nodes_name" {
  type        = string
  description = "The name of the resource group to be used to provision AKS Node resources."
  default = "#{rgAksNodesName}#"
}

variable "location" {
  type        = string
  description = "The location to create azure resources within."
  default = "#{location}#"
}

variable "acr_name" { 
  description = "The name of the Azure Container Registry instance."
  type        = string
  default = "#{acrName}#"
}

variable "aks_name" { 
  description = "The name of the AKS instance."
  type        = string
  default = "#{aksName}#"
}

variable "aks_workload_identity_name" { 
  description = "The name of the AKS workload identity."
  type        = string
  default = "#{aksWorkloadIdentityName}#"
}

variable "aks_federated_identity_name" { 
  description = "The name of the AKS federated identity."
  type        = string
  default = "#{aksFederatedIdentityName}#"
}

variable "aks_namespace" { 
  description = "The default namespace to be set on AKS."
  type        = string
  default = "#{aksNamespace}#"
}

variable "aks_workload_identity_service_account_name" { 
  description = "The name of the service account to use on AKS."
  type        = string
  default = "#{aksWorkloadIdentityServiceAccountName}#"
}

variable "aks_vm_size" {
  description = "Kubernetes VM size."
  type        = string
  default = "#{aksVmSize}#"
}

variable "aks_node_count" {
  description = "Number of nodes to deploy for Kubernetes"
  type        = number
  default = #{aksNodeCount}#
}

variable "kv_name" { 
  description = "The name of the Key Vault instance."
  type        = string
  default = "#{kvName}#"
}

variable "sql_server_name" { 
  description = "The name of the Azure SQL Server."
  type        = string
  default = "#{sqlServerName}#"
}

variable "sql_elasticpool_name" { 
  description = "The name of the Azure SQL Elastic Pool."
  type        = string
  default = "#{sqlElasticPoolName}#"
}

variable "sql_ad_admin_username" { 
  description = "The username of the Azure AD Sql Administrator."
  type        = string
  default = "#{sqlAdAdminUsername}#"
}