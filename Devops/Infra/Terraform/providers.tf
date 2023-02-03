terraform {
  backend "azurerm" {}
}

# Configure the Azure providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.40.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
    mssql = {
      source = "betr-io/mssql"
      version = "~> 0.2.7"
    }
  }

  required_version = ">= 1.1.0"
}

# Configure the Azure Providers

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Configure the Azure Active Directory Provider
provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
  subscription_id = data.azurerm_client_config.current.subscription_id
}