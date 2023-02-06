data "azurerm_client_config" "current" {}

### Core Resource Group

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
  node_resource_group = var.rg_aks_nodes_name
  workload_identity_enabled = true
  oidc_issuer_enabled = true

  storage_profile {
    blob_driver_enabled = true
  }

  default_node_pool {
    name            = var.aks_namespace
    node_count      = var.aks_node_count
    vm_size         = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }
}

# data "azurerm_kubernetes_cluster" "aks" {
#   name                = var.aks_name
#   resource_group_name = azurerm_resource_group.default.name
# }

# data "azurerm_lb" "aks" {
#   name                = "kubernetes"
#   resource_group_name = var.rg_aks_nodes_name
# }

# data "azurerm_lb_backend_address_pool" "aks" {
#   name            = "kubernetes"
#   loadbalancer_id = data.azurerm_lb.aks.id
# }

# output "azurerm_lb" {
#   value = data.azurerm_lb.aks
# }

# output "azurerm_lb_backend_address_pool" {
#   value = data.azurerm_lb_backend_address_pool.aks
# }

# output "aks_vnet_id" {
#   value = data.azurerm_lb_backend_address_pool.aks.backend_address.0.virtual_network_id
# }


# data "azurerm_virtual_network" "aks" {
#   resource_group_name = var.rg_aks_nodes_name

#   depends_on = [azurerm_kubernetes_cluster.default]
# }

# locals {
#   aks_vnet_id = data.azurerm_kubernetes_cluster.aks.agent_pool_profile[0].vnet_subnet_id
#   aks_subnet_id = data.azurerm_virtual_network.aks.subnets[0].id[0]
#   aks_vnet_name = data.azurerm_virtual_network.aks.name[0]
# }

# resource "null_resource" "aks_network" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       az network vnet list --resource-group ${var.rg_aks_nodes_name} --query '[0].id' -o tsv"
#     EOT
#   }

#   depends_on = [
#     azurerm_kubernetes_cluster.default
#   ]
# }


# output "aks_vnet_id" {
#   value = "${local-exec.stdout}"
# }

resource "null_resource" "az_login" {
  provisioner "local-exec" {
    command = "az login --service-principal --username ${data.azurerm_client_config.current.client_id} --password ${var.azClientSecret}  --tenant ${data.azurerm_client_config.current.tenant_id}"
  }

  depends_on = [
    azurerm_kubernetes_cluster.default
  ]
}

data "external" "aks_vnet_id" {
  program = [
    "az","network","vnet","list","--resource-group","${var.rg_aks_nodes_name}","--query","'[0].id'","-o","tsv"
  ]

  depends_on = [null_resource.az_login]
}

# output "aks_vnet_id" {
#   description = "VNet ID of AKS Cluster"
#   value       = data.external.aks_vnet_id.result
# }



#   depends_on = [azurerm_kubernetes_cluster.default]
# }



# data "azurerm_subnet" "aks" {
#   name                 = "aks-subnet"
#   virtual_network_name = local.aks_vnet_name
#   resource_group_name  = var.rg_aks_nodes_name

#   depends_on = [data.external.aks_vnet_id]
# }

# resource "azurerm_role_assignment" "default" {
#   principal_id                     = azurerm_kubernetes_cluster.default.kubelet_identity[0].object_id
#   role_definition_name             = "AcrPull"
#   scope                            = azurerm_container_registry.default.id
#   skip_service_principal_aad_check = true
# }

# resource "azurerm_user_assigned_identity" "aks" {
#   location            = azurerm_resource_group.default.location
#   name                = "${var.aks_workload_identity_name}"
#   resource_group_name = azurerm_resource_group.default.name
# }

# resource "azurerm_federated_identity_credential" "aks" {
#   name                  = "${var.aks_federated_identity_name}"
#   resource_group_name   = azurerm_resource_group.default.name
#   parent_id             = azurerm_user_assigned_identity.aks.id
#   audience              = ["api://AzureADTokenExchange"]
#   issuer                = azurerm_kubernetes_cluster.default.oidc_issuer_url
#   subject               = "system:serviceaccount:${var.aks_namespace}:${var.aks_workload_identity_service_account_name}"
# }

# ### Key Vault

# resource "azurerm_key_vault" "default" {
#   name                       = "${var.kv_name}"
#   resource_group_name        = azurerm_resource_group.default.name
#   location                   = azurerm_resource_group.default.location
#   tenant_id                  = data.azurerm_client_config.current.tenant_id
#   soft_delete_retention_days = 7
#   purge_protection_enabled   = false
#   sku_name = "standard"
# }

# resource "azurerm_key_vault_access_policy" "superadmin" {
#   key_vault_id = azurerm_key_vault.default.id

#   tenant_id = data.azurerm_client_config.current.tenant_id
#   object_id = data.azurerm_client_config.current.object_id

#   secret_permissions = [
#     "Backup",
#     "Delete",
#     "Get",
#     "List",
#     "Purge",
#     "Recover",
#     "Restore",
#     "Set"
#   ]
# }

# resource "azurerm_key_vault_access_policy" "aks" {
#   key_vault_id = azurerm_key_vault.default.id

#   tenant_id = data.azurerm_client_config.current.tenant_id
#   object_id = azurerm_user_assigned_identity.aks.principal_id

#   secret_permissions = [
#     "Get",
#     "List",
#     "Set"
#   ]
# }

# ### Azure SQL Server

# resource "random_password" "sql" {
#   length           = 20
#   special          = true
# }

# resource "azurerm_key_vault_secret" "sql" {
#   name         = "sql-admin-password"
#   value        = random_password.sql.result
#   key_vault_id = azurerm_key_vault.default.id
#   depends_on = [ azurerm_key_vault.default,azurerm_key_vault_access_policy.superadmin ]
# }

# resource "azurerm_mssql_server" "default" {
#   name                         = var.sql_server_name
#   resource_group_name          = azurerm_resource_group.default.name
#   location                     = azurerm_resource_group.default.location
#   version                      = "12.0"
#   administrator_login          = var.sql_admin_username
#   administrator_login_password = azurerm_key_vault_secret.sql.value

#   identity {
#     type = "SystemAssigned"
#   }

#   azuread_administrator {
#     azuread_authentication_only = false
#     login_username = var.sql_ad_admin_username
#     object_id      = var.sql_ad_admin_object_id
#   }
# }

# resource "azurerm_mssql_elasticpool" "default" {
#   name                = var.sql_elasticpool_name
#   resource_group_name = azurerm_resource_group.default.name
#   location            = azurerm_resource_group.default.location
#   server_name         = azurerm_mssql_server.default.name
#   license_type        = "LicenseIncluded"
#   max_size_gb         = 5

#   sku {
#     name     = var.sql_elasticpool_sku_name
#     tier     = var.sql_elasticpool_sku_tier
#     family   = var.sql_elasticpool_sku_family
#     capacity = var.sql_elasticpool_sku_capacity
#   }

#   per_database_settings {
#     min_capacity = 0.25
#     max_capacity = 2
#   }
# }
# resource "azurerm_private_endpoint" "sql" {
#   name                           = var.sql_private_endpoint_name
#   location                       = azurerm_resource_group.default.location
#   resource_group_name            = azurerm_resource_group.default.name
#   subnet_id                      = local.aks_subnet_id
#   custom_network_interface_name  = var.sql_private_endpoint_nic_name

#   private_service_connection {
#     name                           = var.sql_private_endpoint_name
#     is_manual_connection           = false
#     private_connection_resource_id = azurerm_mssql_server.default.id
#     subresource_names              = ["sqlServer"]
#   }
# }

# data "azurerm_private_endpoint_connection" "sql" {
#   name                = azurerm_private_endpoint.sql.name
#   resource_group_name = azurerm_resource_group.default.name
# }

# resource "azurerm_private_dns_zone" "sql" {
#   name                = "privatelink.database.windows.net"
#   resource_group_name = azurerm_resource_group.default.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
#   name                  = "vnet-private-zone-link"
#   resource_group_name   = azurerm_resource_group.default.name
#   private_dns_zone_name = azurerm_private_dns_zone.sql.name
#   virtual_network_id    = local.aks_vnet_id
#   registration_enabled  = true
# }

# resource "azurerm_private_dns_a_record" "sql" {
#   name                = azurerm_mssql_server.default.name
#   zone_name           = azurerm_private_dns_zone.sql.name
#   resource_group_name = azurerm_resource_group.default.name
#   ttl                 = 300
#   records             = [data.azurerm_private_endpoint_connection.sql.private_service_connection.0.private_ip_address]
# }

# data "http" "myip" {
#   url = "https://ipv4.icanhazip.com/"
# }

# resource "azurerm_mssql_firewall_rule" "default" {
#   name                = var.sql_firewall_rule_build_agent_name
#   server_id           = azurerm_mssql_server.default.id
#   start_ip_address    = "${chomp(data.http.myip.response_body)}"
#   end_ip_address      = "${chomp(data.http.myip.response_body)}"

#   depends_on = [ data.http.myip ]
# }

# resource "azurerm_mssql_database" "default" {
#   for_each = toset(var.tenants)
#   name                = each.value
#   server_id           = azurerm_mssql_server.default.id
#   elastic_pool_id     = azurerm_mssql_elasticpool.default.id

#   depends_on = [ azurerm_mssql_firewall_rule.default ]
# }

# resource "mssql_user" "aks" {
#   for_each = toset(var.tenants)
#   server {
#     host = azurerm_mssql_server.default.fully_qualified_domain_name
#     login {
#       username = var.sql_admin_username
#       password = azurerm_key_vault_secret.sql.value
#     }
#   }

#   database  = each.value
#   username  = azurerm_user_assigned_identity.aks.name
#   object_id = azurerm_user_assigned_identity.aks.client_id
#   roles     = ["db_owner"]

#   depends_on = [ azurerm_mssql_database.default ]
# }