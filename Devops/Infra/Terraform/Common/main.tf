data "azurerm_client_config" "current" {}

### Core Resource Group
resource "azurerm_resource_group" "default" {
  name     = var.rg_name
  location = var.location
}

### Azure Container Registry
resource "azurerm_container_registry" "default" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  sku                 = "Basic"
}