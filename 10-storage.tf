
locals {
  backupStorageName = "sqlbck${random_string.random.result}stg"

}

#Create the diagnostic storage account
module sqldiag {
  source                   = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_account?ref=v1.0.1"
  env                      = var.env
  userDefinedString        = "sqldiag"
  resource_group           = local.resource_groups_L1.Logs
  account_tier             = var.sqlServerConfig.storageAccountTier
  account_kind             = var.sqlServerConfig.storageAccountKind
  account_replication_type = var.sqlServerConfig.storageAccountReplicationType
  tags                     = var.tags
}

#Create the storage account that will hold the SQL Backups
module sqlbackup {
  source                   = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_account?ref=v1.0.1"
  env                      = var.env
  userDefinedString        = local.backupStorageName
  resource_group           = local.resource_groups_L1.Logs
  account_tier             = var.sqlServerConfig.storageAccountTier
  account_kind             = var.sqlServerConfig.storageAccountKind
  account_replication_type = var.sqlServerConfig.storageAccountReplicationType
  tags                     = var.tags
}


