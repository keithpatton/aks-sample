variable "tenants" {
  type = list(object({
    name = string,
    group = string
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

variable "aks_namespace_default" { 
  description = "The app's default namespace to be used on AKS."
  type        = string
  default     = "#{aksNamespaceDefault}#"
}

variable "aks_workload_identity_name_prefix" { 
  description = "The name prefix for the Azure Managed identity used for AKS. Tenant Group added dynamically from Tenants List"
  type        = string
  default     = "#{aksWorkloadIdentityNamePrefix}#"
}

variable "aks_federated_identity_name_prefix" { 
  description = "The name prefix of the federated identity used for AKS. Tenant Group added dynamically from Tenants List"
  type        = string
  default     = "#{aksFederatedIdentityNamePrefix}#"
}

variable "aks_workload_identity_service_account_name" { 
  description = "The name of the service account to set on AKS."
  type        = string
  default     = "#{aksWorkloadIdentityServiceAccountName}#"
}

variable "aks_workload_identity_name_default_suffix" { 
  description = "The namespace suffix to be used on AKS for app levelwork (e.g. jobs)"
  type        = string
  default     = "#{aksWorkloadIdentityNameDefaultSuffix}#"
}

variable "kv_name" { 
  description = "The name of the Key Vault instance."
  type        = string
  default     = "#{kvName}#"
}

variable "sql_db_license_type" { 
  description = "The license type of the SQL DB"
  type        = string
  default     = "#{sqlDbLicenseType}#"
}

variable "sql_db_sku_name" { 
  description = "The sku name of the SQL DB"
  type        = string
  default     = "#{sqlDbSkuName}#"
}

variable "sql_db_storage_account_type" { 
  description = "The storage account type for the SQL DB"
  type        = string
  default     = "#{sqlDbStorageAccountType}#"
}

variable "sql_admin_username" { 
  description = "The username of the Sql Administrator."
  type        = string
  default     = "#{sqlAdminUsername}#"
}

variable "sql_server_name" { 
  description = "The name of the Azure SQL Server."
  type        = string
  default     = "#{sqlServerName}#"
}

variable "sql_firewall_rule_build_agent_name" { 
  description = "The name of the sql firewall rule applying for the build agent."
  type        = string
  default     = "#{sqlFirewallRuleBuildAgentName}#"
}