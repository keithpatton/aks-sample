### Data Blocks

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  resource_group_name = var.rg_name
}

data "azurerm_mssql_server" "sql" {
  name                = var.sql_server_name
  resource_group_name = var.rg_name
}

data "azurerm_key_vault" "kv" {
  name                = var.kv_name
  resource_group_name = var.rg_name
}

data "azurerm_key_vault_secret" "sql" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com/"
}

### Locals

locals {
  # identity for all tenant groups and app level
  identity_names = concat(distinct( [for t in var.tenants: t.group]), [var.aks_workload_identity_name_default_suffix])
}

# AKS Workload Identities

resource "azurerm_user_assigned_identity" "aks" {
  for_each =  {for name in local.identity_names: name => name}
  location            = var.location
  name                = "${var.aks_workload_identity_name_prefix}${each.value}"
  resource_group_name = var.rg_name
}

resource "azurerm_federated_identity_credential" "aks" {
  for_each =  {for name in local.identity_names: name => name}
  name                  = "${var.aks_federated_identity_name_prefix}${each.value}"
  resource_group_name   = var.rg_name
  parent_id             = lookup(azurerm_user_assigned_identity.aks[each.value], "id")
  audience              = ["api://AzureADTokenExchange"]
  issuer                = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject = "${each.value == var.aks_workload_identity_name_default_suffix ? "system:serviceaccount:${var.aks_namespace_jobs}:${var.aks_workload_identity_service_account_name}" : "system:serviceaccount:${var.aks_namespace_prefix}${each.value}:${var.aks_workload_identity_service_account_name}"}"

}

### Key Vault Access Policies for each Managed Identity

resource "azurerm_key_vault_access_policy" "aks" {
  for_each =  {for name in local.identity_names: name => name}
  key_vault_id = data.azurerm_key_vault.kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = lookup(azurerm_user_assigned_identity.aks[each.value], "principal_id")

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}

### Azure SQL Server DBs, one per tenant

resource "azurerm_mssql_firewall_rule" "default" {
  name                = var.sql_firewall_rule_build_agent_name
  server_id           = data.azurerm_mssql_server.sql.id
  start_ip_address    = "${chomp(data.http.myip.response_body)}"
  end_ip_address      = "${chomp(data.http.myip.response_body)}"

  depends_on = [ data.http.myip ]
}

resource "azurerm_mssql_database" "default" {
  for_each =  {for tenant in var.tenants:  tenant.name => tenant}
  name                = each.value.name
  server_id           = data.azurerm_mssql_server.sql.id
  
  max_size_gb          = 2
  license_type         = var.sql_db_license_type
  sku_name             = var.sql_db_sku_name
  storage_account_type = var.sql_db_storage_account_type

  depends_on = [ azurerm_mssql_firewall_rule.default ]
}

