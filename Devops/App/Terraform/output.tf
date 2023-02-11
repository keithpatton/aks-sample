output "aks_identity_client_ids" {
  value = [for identity in azurerm_user_assigned_identity.aks: {
      "name": identity.name,
      "client_id": identity.client_id
    }]
}