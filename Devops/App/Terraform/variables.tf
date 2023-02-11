variable "tenants" {
  type = list(object({
    name = string
  }))
  description = "Tenant List"
  default     = #{tenantsJson}#
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group to be used to provision core Azure resources."
  default     = "#{rgName}#"
}

variable "location" {
  type        = string
  description = "The location to create azure resources within."
  default     = "#{location}#"
}

variable "aks_name" { 
  description = "The name of the AKS instance."
  type        = string
  default     = "#{aksName}#"
}

variable "aks_namespace_prefix" { 
  description = "The namespace prefix to be set on AKS. Tenant Group added dynamically from Tenants List"
  type        = string
  default     = "#{aksNamespacePrefix}#"
}

variable "aks_workload_identity_service_account_name" { 
  description = "The name of the service account to set on AKS."
  type        = string
  default     = "#{aksWorkloadIdentityServiceAccountName}#"
}

variable "aks_workload_identity_name_prefix" { 
  description = "The name prefix for the workload identity used for AKS. Tenant Group added dynamically from Tenants List"
  type        = string
  default     = "#{aksWorkloadIdentityNamePrefix}#"
}

variable "aks_federated_identity_name_prefix" { 
  description = "The name prefix of the federated identity used for AKS. Tenant Group added dynamically from Tenants List"
  type        = string
  default     = "#{aksFederatedIdentityNamePrefix}#"
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

variable "sql_admin_username" { 
  description = "The username of the Sql Administrator."
  type        = string
  default     = "#{sqlAdminUsername}#"
}









variable "aks_storage_account_name" {
  description = "Name of the storage account to use with AKS."
  type        = string
  default     = "#{aksStorageAccountName}#"
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

variable "sql_firewall_rule_build_agent_name" { 
  description = "The name of the sql firewall rule applying for the build agent."
  type        = string
  default     = "#{sqlFirewallRuleBuildAgentName}#"
}