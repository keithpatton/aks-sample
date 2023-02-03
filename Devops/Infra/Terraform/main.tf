### Resource Group

resource "azurerm_resource_group" "default" {
  name     = "${var.rg_name}"
  location = var.location
}

### Azure Container Registry

resource "azurerm_container_registry" "default" {
  name                = "${var.acr_name}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  sku                 = "Basic"
}

### AKS Cluster

resource "azurerm_kubernetes_cluster" "default" {
  name                = "${var.aks_name}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  dns_prefix          = "${var.aks_name}"
  node_resource_group = "${var.rg_aks_nodes_name}"

  storage_profile {
    blob_driver_enabled = true
  }

  workload_identity_enabled = true

  oidc_issuer_enabled = true

  default_node_pool {
    name       = var.aks_namespace
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "default" {
  principal_id                     = azurerm_kubernetes_cluster.default.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.default.id
  skip_service_principal_aad_check = true
}

### Azure Workload Identity - AKS 

resource "azurerm_user_assigned_identity" "aks" {
  location            = azurerm_resource_group.default.location
  name                = "${var.aks_workload_identity_name}"
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_federated_identity_credential" "aks" {
  name                  = "${var.aks_federated_identity_name}"
  resource_group_name   = azurerm_resource_group.default.name
  parent_id             = azurerm_user_assigned_identity.aks.id
  audience              = ["api://AzureADTokenExchange"]
  issuer                = azurerm_kubernetes_cluster.default.oidc_issuer_url
  subject               = "system:serviceaccount:${var.aks_namespace}:${var.aks_workload_identity_service_account_name}"
}

### Key Vault

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "default" {
  name                       = "${var.kv_name}"
  resource_group_name        = azurerm_resource_group.default.name
  location                   = azurerm_resource_group.default.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  sku_name = "standard"
}

### Key Vault Access Policy - AKS

resource "azurerm_key_vault_access_policy" "superadmin" {
  key_vault_id = azurerm_key_vault.default.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set"
  ]
}

resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.default.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.aks.principal_id

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}

### Passwords

resource "random_password" "sql" {
  length           = 20
  special          = true
}

resource "azurerm_key_vault_secret" "sql" {
  name         = "sql-admin-password"
  value        = random_password.sql.result
  key_vault_id = azurerm_key_vault.default.id
  depends_on = [ azurerm_key_vault.default ]
}

### Azure SQL Elastic Pool

data "azurerm_client_config" "current" {}

data "azuread_user" "sql" {
  user_principal_name = var.sql_ad_admin_username
}

resource "azurerm_sql_server" "default" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.default.name
  location                     = azurerm_resource_group.default.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = azurerm_key_vault_secret.sql

  identity {
    type = "SystemAssigned"
  }

  azuread_administrator {
    azuread_authentication_only = true
    login_username = var.sql_ad_admin_username
    object_id      = azuread_user.sql.object_id
  }
}

resource "azurerm_mssql_elasticpool" "default" {
  name                = var.sql_elasticpool_name
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  server_name         = azurerm_sql_server.default.name
  license_type        = "LicenseIncluded"
  max_size_gb         = 5

  sku {
    name     = "GP_Gen5"
    tier     = "GeneralPurpose"
    family   = "Gen5"
    capacity = 2
  }

  per_database_settings {
    min_capacity = 0.25
    max_capacity = 2
  }
}

resource "azurerm_sql_database" "sql" {
  for_each = toset(var.tenants)
  name                = each.name
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  server_name         = azurerm_sql_server.default.name
  elastic_pool_name   = var.sql_elasticpool_name
}

resource "mssql_user" "aks" {
  for_each = toset(var.tenants)
  server {
    host = azurerm_sql_server.default.name
    azure_login {}
  }

  database  = each.name
  username  = azurerm_user_assigned_identity.aks.name
  object_id = azurerm_user_assigned_identity.aks.client_id

  roles     = ["db_owner"]
}