data "azurerm_key_vault" "keyvaultsecrets" {
  name                = "${var.keyVaultConfig.existingVaultName}"
  resource_group_name = "${var.keyVaultConfig.existingRGName}"
}

data "azurerm_key_vault_secret" "localAdminPasswordSecret" {
  name         = "${var.keyVaultConfig.localAdminPasswordSecret}"
  key_vault_id = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}

data "azurerm_key_vault_secret" "domainAdminPasswordSecret" {
  name         = "${var.keyVaultConfig.domainAdminPasswordSecret}"
  key_vault_id = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}

data "azurerm_key_vault_secret" "sqlAdminPasswordSecret" {
  name         = "${var.sqlServerConfig.sqlServerServiceAccountPasswordSecret}"
  key_vault_id = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}

data "azurerm_subnet" "subnet" {
  name                 = "${var.vnetConfig.dbSubnetName}"
  virtual_network_name = "${var.vnetConfig.existingVnetName}"
  resource_group_name  = "${var.vnetConfig.existingVnetRG}"
}

data "azurerm_virtual_network" "vnet" {
  name = "${var.vnetConfig.existingVnetName}"
  resource_group_name  = "${var.vnetConfig.existingVnetRG}"
}

# =============== TEMPLATES =============== #
data "template_file" "sqlvm" {
  template = file("./Templates/SQLVirtualMachine.json")
}