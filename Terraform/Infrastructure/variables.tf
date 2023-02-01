variable "app_name" {
  type        = string
  description = "The root name of the application, as an alphanumeric short value up to 16 chars. This name will be used when creating solution resources on Azure."
}

variable "location" {
  type        = string
  description = "The Azure location on which to create the resources."
}

variable "aks_namespace" {
  description = "The default namespace to be set on AKS."
  type        = string
}

variable "unique_suffix" {
  type        = string
  description = "A few characters (no more than 3) to uniquely identity resources that require global uniqueness"
}

variable "aks_vm_size" {
  description = "Kubernetes VM size."
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes to deploy for Kubernetes"
  type        = number
}