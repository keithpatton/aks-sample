variable "rg_common_name" {
  type        = string
  description = "The name of the common resource group to be used to provision common Azure resources."
  default     = "#{rgCommonName}#"
}

variable "location" {
  type        = string
  description = "The common location to create azure resources within."
  default     = "#{location}#"
}

variable "acr_name" { 
  description = "The name of the Azure Container Registry instance."
  type        = string
  default     = "#{acrName}#"
}