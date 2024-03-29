﻿### Data Blocks

data "azurerm_client_config" "current" {}

data "azurerm_container_registry" "default" {
  name                = var.acr_name
  resource_group_name = var.rg_common_name
}

### Core Resource Group
resource "azurerm_resource_group" "default" {
  name     = "${var.rg_name}"
  location = var.location
}

### AKS Cluster
resource "azurerm_kubernetes_cluster" "default" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  dns_prefix          = var.aks_name
  node_resource_group = var.rg_aks_nodes_name
  workload_identity_enabled = true
  oidc_issuer_enabled = true

  storage_profile {
    blob_driver_enabled = true
  }

  default_node_pool {
    name            = var.aks_nodepool_name
    node_count      = var.aks_node_count
    vm_size         = var.aks_vm_size
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_virtual_network" "aks" {
  resource_group_name = var.rg_aks_nodes_name
  name                = var.aks_vnet_name

  depends_on = [azurerm_kubernetes_cluster.default]
}

data "azurerm_subnet" "aks" {
  resource_group_name  = var.rg_aks_nodes_name
  virtual_network_name = var.aks_vnet_name
  name                 = data.azurerm_virtual_network.aks.subnets.0
}

resource "azurerm_role_assignment" "default" {
  principal_id                     = azurerm_kubernetes_cluster.default.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = data.azurerm_container_registry.default.id
  skip_service_principal_aad_check = true
}

### Key Vault

resource "azurerm_key_vault" "default" {
  name                       = "${var.kv_name}"
  resource_group_name        = azurerm_resource_group.default.name
  location                   = azurerm_resource_group.default.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name = "standard"
}

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

### Azure SQL Server

resource "random_password" "sql" {
  length           = 20
  special          = true
}

resource "azurerm_key_vault_secret" "sql" {
  name         = "sql-admin-password"
  value        = random_password.sql.result
  key_vault_id = azurerm_key_vault.default.id
  depends_on = [ azurerm_key_vault.default,azurerm_key_vault_access_policy.superadmin ]
}

resource "azurerm_mssql_server" "default" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.default.name
  location                     = azurerm_resource_group.default.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = azurerm_key_vault_secret.sql.value

  identity {
    type = "SystemAssigned"
  }

  azuread_administrator {
    azuread_authentication_only = false
    login_username = var.sql_ad_admin_username
    object_id      = var.sql_ad_admin_object_id
  }
}

resource "azurerm_private_endpoint" "sql" {
  name                           = var.sql_private_endpoint_name
  location                       = azurerm_resource_group.default.location
  resource_group_name            = azurerm_resource_group.default.name
  subnet_id                      = data.azurerm_subnet.aks.id
  custom_network_interface_name  = var.sql_private_endpoint_nic_name

  private_service_connection {
    name                           = var.sql_private_endpoint_name
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.default.id
    subresource_names              = ["sqlServer"]
  }
}

data "azurerm_private_endpoint_connection" "sql" {
  name                = azurerm_private_endpoint.sql.name
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "vnet-private-zone-link"
  resource_group_name   = azurerm_resource_group.default.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = data.azurerm_virtual_network.aks.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "sql" {
  name                = azurerm_mssql_server.default.name
  zone_name           = azurerm_private_dns_zone.sql.name
  resource_group_name = azurerm_resource_group.default.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.sql.private_service_connection.0.private_ip_address]
}