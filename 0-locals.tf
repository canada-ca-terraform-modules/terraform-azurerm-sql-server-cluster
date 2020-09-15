locals {
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
