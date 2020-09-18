#Create the primary SQL server
module "sqlvm1" {
  source                 = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-windows_virtual_machine?ref=v1.1.2"
  custom_data            = base64encode(file("${path.module}/scripts/Configure-DSC.ps1"))
  env                    = var.env
  userDefinedString      = var.sqlServerConfig.vmName
  postfix                = "1"
  resource_group         = var.resource_group
  admin_username         = var.adminUsername
  admin_password         = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  subnet                 = var.vnetConfig.sqlSubnet
  availability_set_id    = azurerm_availability_set.sqlAS.id
  public_ip              = false
  use_nic_nsg            = var.sqlServerConfig.use_nic_nsg
  vm_size                = var.sqlServerConfig.vmSize
  data_disk_sizes_gb     = [var.sqlServerConfig.dataDisks.diskSizeGB, var.sqlServerConfig.dataDisks.diskSizeGB]
  os_managed_disk_type   = lookup(var.sqlServerConfig, "os_managed_disk_type", "StandardSSD_LRS")
  data_managed_disk_type = lookup(var.sqlServerConfig, "data_managed_disk_type", "StandardSSD_LRS")
  storage_image_reference = {
    publisher = var.sqlServerConfig.imageReference.sqlImagePublisher
    offer     = var.sqlServerConfig.imageReference.offer
    sku       = var.sqlServerConfig.imageReference.sku
    version   = var.sqlServerConfig.imageReference.version
  }
  domainToJoin = {
    domainName        = var.adConfig.domainName
    domainUsername    = var.domainUsername
    domainPassword    = data.azurerm_key_vault_secret.domainAdminPasswordSecret.value
    domainJoinOptions = 3
    ouPath            = var.adConfig.serverOUPath
  }
  tags = var.tags
  asg  = var.asg
}

#Create the secondary SQL Server
module "sqlvm2" {
  source                 = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-windows_virtual_machine?ref=v1.1.2"
  custom_data            = base64encode(file("${path.module}/scripts/Configure-DSC.ps1"))
  env                    = var.env
  userDefinedString      = var.sqlServerConfig.vmName
  subnet                 = var.vnetConfig.sqlSubnet
  postfix                = "2"
  resource_group         = var.resource_group
  admin_username         = var.adminUsername
  admin_password         = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  availability_set_id    = azurerm_availability_set.sqlAS.id
  public_ip              = false
  use_nic_nsg            = var.sqlServerConfig.use_nic_nsg
  vm_size                = var.sqlServerConfig.vmSize
  data_disk_sizes_gb     = [var.sqlServerConfig.dataDisks.diskSizeGB, var.sqlServerConfig.dataDisks.diskSizeGB]
  os_managed_disk_type   = lookup(var.sqlServerConfig, "os_managed_disk_type", "StandardSSD_LRS")
  data_managed_disk_type = lookup(var.sqlServerConfig, "data_managed_disk_type", "StandardSSD_LRS")
  storage_image_reference = {
    publisher = var.sqlServerConfig.imageReference.sqlImagePublisher
    offer     = var.sqlServerConfig.imageReference.offer
    sku       = var.sqlServerConfig.imageReference.sku
    version   = var.sqlServerConfig.imageReference.version
  }
  domainToJoin = {
    domainName        = var.adConfig.domainName
    domainUsername    = var.domainUsername
    domainPassword    = data.azurerm_key_vault_secret.domainAdminPasswordSecret.value
    domainJoinOptions = 3
    ouPath            = var.adConfig.serverOUPath
  }
  tags = var.tags
  asg  = var.asg
}

#Create the SQL Witness.  Could be switched for a blob storage if desired
module "sqlvmw" {
  source              = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-windows_virtual_machine?ref=v1.1.2"
  custom_data         = base64encode(file("${path.module}/scripts/Configure-DSC.ps1"))
  env                 = var.env
  userDefinedString   = var.witnessServerConfig.vmName
  postfix             = "1"
  location            = var.location
  resource_group      = var.resource_group
  subnet              = var.vnetConfig.sqlSubnet
  admin_username      = var.adminUsername
  admin_password      = data.azurerm_key_vault_secret.localAdminPasswordSecret.value
  availability_set_id = azurerm_availability_set.sqlAS.id
  public_ip           = false
  use_nic_nsg         = var.witnessServerConfig.use_nic_nsg
  vm_size             = var.witnessServerConfig.vmSize
  data_disk_sizes_gb  = [var.witnessServerConfig.dataDisks.diskSizeGB, var.witnessServerConfig.dataDisks.diskSizeGB]
  storage_image_reference = {
    publisher = var.witnessServerConfig.imageReference.publisher
    offer     = var.witnessServerConfig.imageReference.offer
    sku       = var.witnessServerConfig.imageReference.sku
    version   = var.witnessServerConfig.imageReference.version
  }
  domainToJoin = {
    domainName        = var.adConfig.domainName
    domainUsername    = var.domainUsername
    domainPassword    = data.azurerm_key_vault_secret.domainAdminPasswordSecret.value
    domainJoinOptions = 3
    ouPath            = var.adConfig.serverOUPath
  }
  os_managed_disk_type   = lookup(var.witnessServerConfig, "os_managed_disk_type", "StandardSSD_LRS")
  data_managed_disk_type = lookup(var.witnessServerConfig, "data_managed_disk_type", "StandardSSD_LRS")
  tags                   = var.tags
  asg                    = var.asg
}

output "sql1" {
  value = module.sqlvm1.name
}

output "sql2" {
  value = module.sqlvm2.name
}

output "sqlw" {
  value = module.sqlvmw.name
}
