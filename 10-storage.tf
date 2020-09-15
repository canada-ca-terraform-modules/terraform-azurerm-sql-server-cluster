

#Create the diagnostic storage account
module sqldiag {
  source                   = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_account?ref=v1.0.1"
  env                      = var.env
  userDefinedString        = "sqldiag"
  resource_group           = var.resource_group_name
  account_tier             = var.sqlServerConfig.storageAccountTier
  account_kind             = var.sqlServerConfig.storageAccountKind
  account_replication_type = var.sqlServerConfig.storageAccountReplicationType
  tags                     = var.tags
}

#Create the storage account that will hold the SQL Backups
module sqlbackup {
  source                   = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_account?ref=v1.0.1"
  env                      = var.env
  userDefinedString        = "sqlbck"
  resource_group           = var.resource_group_name
  account_tier             = var.sqlServerConfig.storageAccountTier
  account_kind             = var.sqlServerConfig.storageAccountKind
  account_replication_type = var.sqlServerConfig.storageAccountReplicationType
  tags                     = var.tags
}


