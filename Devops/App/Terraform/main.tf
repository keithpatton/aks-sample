### Data Blocks

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  resource_group_name = var.rg_name
}

data "azurerm_key_vault" "kv" {
  name                = var.kv_name
  resource_group_name = var.rg_name
}

data "azurerm_mssql_server" "sql" {
  name                = var.sql_server_name
  resource_group_name = var.rg_name
}

data "azurerm_mssql_elasticpool" "sql" {
  name                = var.sql_elasticpool_name
  resource_group_name = var.rg_name
  server_name         = var.sql_server_name
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
  tenant_groups = distinct(map(var.tenants, "group"))
}

# AKS Workload Identity, one per tenant group

resource "azurerm_user_assigned_identity" "aks" {
  for_each =  {for group in local.tenant_groups: group => group}
  location            = var.location
  name                = var.aks_workload_identity_name_prefix + each.value
  resource_group_name = var.rg_name
}

resource "azurerm_federated_identity_credential" "aks" {
  for_each =  {for group in local.tenant_groups: group => group}
  name                  = var.app_aks_federated_identity_name_prefix + each.value.group
  resource_group_name   = var.rg_name
  parent_id             = azurerm_user_assigned_identity.aks.id
  audience              = ["api://AzureADTokenExchange"]
  issuer                = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject               = "system:serviceaccount:" + var.aks_namespace_prefix + each.value + ":" + var.aks_workload_identity_service_account_name
}

### Key Vault Access Policy, one per tenant group

resource "azurerm_key_vault_access_policy" "aks" {
  for_each =  {for group in local.tenant_groups: group => group}
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
  elastic_pool_id     = data.azurerm_mssql_elasticpool.default.id

  depends_on = [ azurerm_mssql_firewall_rule.default ]
}

### Azure SQL Server DB Users, one per tenant, using tenant group managed identity

resource "mssql_user" "aks" {
  for_each =  {for tenant in var.tenants:  tenant.name => tenant}
  server {
    host = azurerm_mssql_server.default.fully_qualified_domain_name
    login {
      username = var.sql_admin_username
      password = azurerm_key_vault_secret.sql.value
    }
  }

  database  = each.value.name
  username  = lookup(azurerm_user_assigned_identity.aks[each.value.group], "name")
  object_id = lookup(azurerm_user_assigned_identity.aks[each.value.group], "client_id")
  roles     = ["db_owner"]

  depends_on = [ azurerm_mssql_database.default, azurerm_user_assigned_identity.aks ]
}