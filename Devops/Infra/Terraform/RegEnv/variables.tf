variable "rg_name" {
  type        = string
  description = "The name of the stage resource group to be used to provision stage Azure resources."
  default     = "#{rgName}#"
}

variable "rg_common_name" {
  type        = string
  description = "The name of the common resource group to be used to provision common Azure resources."
  default     = "#{rgCommonName}#"
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

variable "aks_nodepool_name" { 
  description = "The name of the AKS Node Pool."
  type        = string
  default     = "#{aksNodepoolName}#"
}

variable "aks_vnet_name" {
  type        = string
  description = "Aks VNet Name - (Temp as not able to retrieve from AKS for some reason)"
  default     = "#{aksVNetName}#"
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