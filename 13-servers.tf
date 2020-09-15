#Create the primary SQL server
module "sqlvm1" {
  source                  = "github.com/canada-ca-terraform-modules/terraform-azurerm_windows_virtual_machine?ref=20200622.2"
  env                     = var.env
  user_defined_string     = var.sqlServerConfig.vmName
  postfix                 = "001"
  resource_group_name     = var.resource_group_name
  admin_username          = var.adminUsername
  admin_password          = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  nic_subnetName          = data.azurerm_subnet.subnet.name
  nic_vnetName            = data.azurerm_virtual_network.vnet.name
  nic_resource_group_name = var.vnetConfig.existingVnetRG
  availability_set_id     = azurerm_availability_set.sqlAS.id
  public_ip               = false
  vm_size                 = var.sqlServerConfig.vmSize
  data_disk_sizes_gb      = [var.sqlServerConfig.dataDisks.diskSizeGB, var.sqlServerConfig.dataDisks.diskSizeGB]
  storage_image_reference = {
    publisher = var.sqlServerConfig.imageReference.sqlImagePublisher
    offer     = var.sqlServerConfig.imageReference.offer
    sku       = var.sqlServerConfig.imageReference.sku
    version   = var.sqlServerConfig.imageReference.version
  }

}

#Create the secondary SQL Server
module "sqlvm2" {
  source                  = "github.com/canada-ca-terraform-modules/terraform-azurerm_windows_virtual_machine?ref=20200622.2"
  env                     = var.env
  user_defined_string     = var.sqlServerConfig.vmName
  postfix                 = "002"
  resource_group_name     = var.resource_group_name
  admin_username          = var.adminUsername
  admin_password          = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  nic_subnetName          = data.azurerm_subnet.subnet.name
  nic_vnetName            = data.azurerm_virtual_network.vnet.name
  nic_resource_group_name = var.vnetConfig.existingVnetRG
  availability_set_id     = azurerm_availability_set.sqlAS.id
  public_ip               = false
  vm_size                 = var.sqlServerConfig.vmSize
  data_disk_sizes_gb      = [var.sqlServerConfig.dataDisks.diskSizeGB, var.sqlServerConfig.dataDisks.diskSizeGB]
  storage_image_reference = {
    publisher = var.sqlServerConfig.imageReference.sqlImagePublisher
    offer     = var.sqlServerConfig.imageReference.offer
    sku       = var.sqlServerConfig.imageReference.sku
    version   = var.sqlServerConfig.imageReference.version
  }

}

#Create the SQL Witness.  Could be switched for a blob storage if desired
module "sqlvmw" {
  source                  = "github.com/canada-ca-terraform-modules/terraform-azurerm_windows_virtual_machine?ref=20200622.2"
  env                     = var.env
  user_defined_string     = var.witnessServerConfig.vmName
  postfix                 = "001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  admin_username          = var.adminUsername
  admin_password          = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  nic_subnetName          = data.azurerm_subnet.subnet.name
  nic_vnetName            = data.azurerm_virtual_network.vnet.name
  nic_resource_group_name = var.vnetConfig.existingVnetRG
  availability_set_id     = azurerm_availability_set.sqlAS.id
  public_ip               = false
  vm_size                 = var.witnessServerConfig.vmSize
  data_disk_sizes_gb      = [var.witnessServerConfig.dataDisks.diskSizeGB, var.witnessServerConfig.dataDisks.diskSizeGB]
  storage_image_reference = {
    publisher = var.witnessServerConfig.imageReference.publisher
    offer     = var.witnessServerConfig.imageReference.offer
    sku       = var.witnessServerConfig.imageReference.sku
    version   = var.witnessServerConfig.imageReference.version
  }
}

