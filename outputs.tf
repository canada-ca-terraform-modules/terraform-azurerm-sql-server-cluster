output "asg" {
  value = var.asg.name
}

output "keyvaultPass" {
  value = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
}
