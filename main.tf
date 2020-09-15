# Template for SQL Server Cluster
# Note if running this many times for testing make sure to delete the AD and DNS objects
terraform {
  required_version = ">= 0.12.1"
  backend "azurerm" {
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.container_name}"
    key                  = "${var.key}"
    access_key           = "${var.access_key}"
  }
}


locals {

  backupStorageName = "sqlbck${random_string.random.result}stg"

  vmSettings = {
    availabilitySets = {
      sqlAvailabilitySetName = "${var.sqlServerConfig.vmName}-avs"
    }
    rdpPort = 3389
  }
  sqlAOEPName       = "${var.sqlServerConfig.vmName}-hadr"
  sqlAOAGName       = "${var.sqlServerConfig.vmName}-ag"
  sqlAOListenerName = "${var.sqlServerConfig.vmName}-lis"
  sharePath         = "${var.sqlServerConfig.vmName}-fsw"
  clusterName       = "${var.sqlServerConfig.vmName}-cl"
  sqlwNicName       = "${var.witnessServerConfig.vmName}-nic"
  keyVaultId        = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}



