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
    name       = var.aks_name
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