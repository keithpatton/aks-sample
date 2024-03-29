﻿terraform {
  backend "azurerm" {}
}

# Configure the Azure providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.40.0"
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