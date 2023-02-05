variable "tenants" {
  type        = list(string)
  description = "Tenant List"
  default     = #{tenantsJson}#
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group to be used to provision core Azure resources."
  default     = "#{rgName}#"
}

variable "rg_aks_nodes_name" {
  type        = string
  description = "The name of the resource group to be used to provision AKS Node resources."
  default     = "#{rgAksNodesName}#"
}

variable "location" {
  type        = string
  description = "The location to create azure resources within."
  default     = "#{location}#"
}

variable "acr_name" { 
  description = "The name of the Azure Container Registry instance."
  type        = string
  default     = "#{acrName}#"
}

variable "aks_name" { 
  description = "The name of the AKS instance."
  type        = string
  default     = "#{aksName}#"
}

variable "aks_workload_identity_name" { 
  description = "The name of the AKS workload identity."
  type        = string
  default     = "#{aksWorkloadIdentityName}#"
}

variable "aks_federated_identity_name" { 
  description = "The name of the AKS federated identity."
  type        = string
  default     = "#{aksFederatedIdentityName}#"
}

variable "aks_namespace" { 
  description = "The default namespace to be set on AKS."
  type        = string
  default     = "#{aksNamespace}#"
}

variable "aks_workload_identity_service_account_name" { 
  description = "The name of the service account to use on AKS."
  type        = string
  default     = "#{aksWorkloadIdentityServiceAccountName}#"
}

variable "aks_storage_account_name" {
  description = "Name of the storage account to use with AKS."
  type        = string
  default     = "#{aksStorageAccountName}#"
}

variable "aks_vm_size" {
  description = "Kubernetes VM size."
  type        = string
  default     = "#{aksVmSize}#"
}

variable "aks_node_count" {
  description = "Number of nodes to deploy for Kubernetes"
  type        = number
  default     = #{aksNodeCount}#
}

variable "aks_vnet_name" {
  description = "Name of VNet for AKS"
  type        = string
  default     = "#{aksVNetName}#"
}

variable "aks_subnet_name" {
  description = "Name of Subnet for AKS"
  type        = string
  default     = "#{aksSubnetName}#"
}

variable "aks_vnet_address_space" {
  description = "IP Address Space for AKS Vnet"
  type        = string
  default     = "#{aksVNetAddressSpace}#"
}

variable "aks_subnet_address_space" {
  description = "IP Address Space for AKS Subnet"
  type        = string
  default     = "#{aksSubnetAddressSpace}#"
}

variable "kv_name" { 
  description = "The name of the Key Vault instance."
  type        = string
  default     = "#{kvName}#"
}

variable "sql_server_name" { 
  description = "The name of the Azure SQL Server."
  type        = string
  default     = "#{sqlServerName}#"
}

variable "sql_elasticpool_name" { 
  description = "The name of the Azure SQL Elastic Pool."
  type        = string
  default     = "#{sqlElasticPoolName}#"
}

variable "sql_elasticpool_sku_name" { 
  description = "The sku name of the Azure SQL Elastic Pool."
  type        = string
  default     = "#{sqlElasticPoolSkuName}#"
}

variable "sql_elasticpool_sku_tier" { 
  description = "The sku tier of the Azure SQL Elastic Pool."
  type        = string
  default     = "#{sqlElasticPoolSkuTier}#"
}

variable "sql_elasticpool_sku_family" { 
  description = "The sku family of the Azure SQL Elastic Pool."
  type        = string
  default     = "#{sqlElasticPoolSkuFamily}#"
}

variable "sql_elasticpool_sku_capacity" { 
  description = "The sku capacity of the Azure SQL Elastic Pool."
  type        = number
  default     = #{sqlElasticPoolSkuCapacity}#
}

variable "sql_admin_username" { 
  description = "The username of the Sql Administrator."
  type        = string
  default     = "#{sqlAdminUsername}#"
}

variable "sql_ad_admin_username" { 
  description = "The username of the Azure AD Sql Administrator. Should have at least Directory Readers role in Azure AD"
  type        = string
  default     = "#{sqlAdAdminUsername}#"
}

variable "sql_ad_admin_object_id" { 
  description = "The object id of the Azure AD Sql Administrator."
  type        = string
  default     = "#{sqlAdAdminObjectId}#"
}

variable "sql_firewall_rule_build_agent_name" { 
  description = "The name of the sql firewall rule applying for the build agent."
  type        = string
  default     = "#{sqlFirewallRuleBuildAgentName}#"
}

variable "sql_private_endpoint_name" { 
  description = "The name of the sql private endpoint."
  type        = string
  default     = "#{sqlPrivateEndpointName}#"
}

variable "sql_private_endpoint_nic_name" { 
  description = "The name of the sql private endpoint network interface."
  type        = string
  default     = "#{sqlPrivateEndpointNicName}#"
}