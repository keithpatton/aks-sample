### Local Variables

locals {
  aks_name             = "aks-${var.app_name}"
  resource_group_name  = "rg-${var.app_name}"
  service_account_name = "sa-workload-identity-${var.app_name}"
  kv_name              = "kv-${var.app_name}-${var.unique_suffix}"
  acr_name             = "acr${var.app_name}${var.unique_suffix}"
}

### Release with Helm

data "azurerm_user_assigned_identity" "aks" {
  name                = "${local.aks_name}"
  resource_group_name = "${local.resource_group_name}"
}

resource "helm_release" "default" {
  name  = "aks-sample"
  chart = "aks-sample"

  set {
    name   = "aksNamespace"
    value  = var.aks_namespace
  }

  set {
    name   = "workloadIdentityServiceAccountName"
    value  = "${local.service_account_name}"
  }

  set {
    name   = "keyVaultName"
    value  = "${local.kv_name}"
  }

  set {
    name   = "azureContainerRegistryName"
    value  = "${local.acr_name}"
  }

  set {
    name   = "workloadIdentityClientId"
    value  = data.azurerm_user_assigned_identity.aks.client_id
  }

}