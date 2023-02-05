data "azurerm_client_config" "current" {}

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

resource "azurerm_resource_group" "aks" {
  name     = var.rg_aks_nodes_name
  location = var.location
}

resource "azurerm_virtual_network" "aks" {
    name                        = var.aks_vnet_name
    location                    = azurerm_resource_group.default.location
    resource_group_name         = azurerm_resource_group.aks.name
    address_space               = [var.aks_vnet_address_space] 
}

resource "azurerm_subnet" "aks" {
    name                        = var.aks_subnet_name
    resource_group_name         = azurerm_resource_group.default.name
    virtual_network_name        = azurerm_virtual_network.aks.name
    address_prefixes            = [var.aks_subnet_address_space]

    depends_on = [ azurerm_virtual_network.aks ]
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = "${var.aks_name}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  dns_prefix          = "${var.aks_name}"
  node_resource_group = azurerm_resource_group.aks.name

  storage_profile {
    blob_driver_enabled = true
  }

  workload_identity_enabled = true

  oidc_issuer_enabled = true

  default_node_pool {
    name            = var.aks_namespace
    node_count      = var.aks_node_count
    vm_size         = var.aks_vm_size
    vnet_subnet_id  = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [ azurerm_subnet.aks ]

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

resource "azurerm_mssql_elasticpool" "default" {
  name                = var.sql_elasticpool_name
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  server_name         = azurerm_mssql_server.default.name
  license_type        = "LicenseIncluded"
  max_size_gb         = 5

  sku {
    name     = var.sql_elasticpool_sku_name
    tier     = var.sql_elasticpool_sku_tier
    family   = var.sql_elasticpool_sku_family
    capacity = var.sql_elasticpool_sku_capacity
  }

  per_database_settings {
    min_capacity = 0.25
    max_capacity = 2
  }

  depends_on = [ azurerm_mssql_server.default ]
}

resource "azurerm_private_endpoint" "sql" {
  name                           = var.sql_private_endpoint_name
  location                       = azurerm_resource_group.default.location
  resource_group_name            = azurerm_resource_group.default.name
  subnet_id                      = azurerm_subnet.aks.id
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
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "sql" {
  name                = azurerm_mssql_server.default.name
  zone_name           = azurerm_private_dns_zone.sql.name
  resource_group_name = azurerm_resource_group.default.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.sql.private_service_connection.0.private_ip_address]
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com/"
}

resource "azurerm_mssql_firewall_rule" "default" {
  name                = var.sql_firewall_rule_build_agent_name
  server_id           = azurerm_mssql_server.default.id
  start_ip_address    = "${chomp(data.http.myip.response_body)}"
  end_ip_address      = "${chomp(data.http.myip.response_body)}"

  depends_on = [ data.http.myip ]
}

resource "azurerm_mssql_database" "default" {
  for_each = toset(var.tenants)
  name                = each.value
  server_id           = azurerm_mssql_server.default.id
  elastic_pool_id     = azurerm_mssql_elasticpool.default.id

  depends_on = [ azurerm_mssql_firewall_rule.default ]
}

resource "mssql_user" "aks" {
  for_each = toset(var.tenants)
  server {
    host = azurerm_mssql_server.default.fully_qualified_domain_name
    login {
      username = var.sql_admin_username
      password = azurerm_key_vault_secret.sql.value
    }
  }

  database  = each.value
  username  = azurerm_user_assigned_identity.aks.name
  object_id = azurerm_user_assigned_identity.aks.client_id
  roles     = ["db_owner"]

  depends_on = [ azurerm_mssql_database.default ]
}