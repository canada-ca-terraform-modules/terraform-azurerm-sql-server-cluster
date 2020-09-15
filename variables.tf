variable "resource_group_name" {
  default = "pws3-test-sql-cluster-rg"
}

variable "keyVaultConfig" {
  default = {
    existingRGName            = "PwS3-GCPS-CRM-KeyVault-RG"
    existingVaultName         = "PwS3-CRM-Keyvault"
    localAdminPasswordSecret  = "server2016DefaultPassword"
    domainAdminPasswordSecret = "adDefaultPassword"
  }
}

variable "secretPasswordName" {
  default = "server2016DefaultPassword"
}

variable "vnetConfig" {
  default = {
    existingVnetName = "PwS3-Infra-NetShared-VNET"
    existingVnetRG   = "PwS3-Infra-NetShared-RG"
    sqlSubnet        = "10.250.29.0/26"
    dbSubnetName     = "PwS3-Shared-DB-CRM"
  }
}

variable "location" {
  description = "The location of the template deployment"
  default     = "canadacentral"
}

variable "adminUsername" {
  description = "The name of the Administrator for the new VMs"
  default     = "azureadmin"
}

variable "domainUsername" {
  description = "The name of the Administrator accounts used to join the domain and to create the service accounts"
  default     = "azureadmin"
}

variable "dnsServerName" {
  default = "PwS3SharedDC01"
}

variable "sqlServerConfig" {
  default = {
    clusterIp            = "169.254.1.15"
    sqlLBIPAddress       = "10.250.29.14"
    sqlLBName            = "TST-SWB"
    sqlAOListenerPort    = "1433"
    vmSize               = "Standard_DS3_v2"
    vmName               = "TST-SWB"
    sqlServerLicenseType = "AHUB"
    sqlpatchingConfig = {
      patchingEnabled               = true
      dayOfWeek                     = "Sunday"
      maintenanceWindowStartingHour = "2"
      maintenanceWindowDuration     = 60
    }
    sqlBackupConfig = {
      backupEnabled         = true
      retentionPeriod       = 30
      enableEncryption      = true
      backupSystemDbs       = true
      backupScheduleType    = "Manual"
      fullBackupFrequency   = "Daily"
      fullBackupStartTime   = 2
      fullBackupWindowHours = 5
      logBackupFrequency    = 60
      password              = "Canada123!"
    }
    imageReference = {
      sqlImagePublisher = "MicrosoftSQLServer"
      offer             = "SQL2016SP2-WS2016"
      sku               = "Enterprise"
      version           = "latest"
    }
    dataDisks = {
      numberOfSqlVMDisks = "2"
      diskSizeGB         = "1024"
    }
    workloadType                          = "OLTP"
    sqlServerServiceAccountUserName       = "svc-tstsql1"
    sqlStorageAccountName                 = "tstsqltest1stg"
    storageAccountTier                    = "Standard"
    storageAccountKind                    = "StorageV2"
    storageAccountReplicationType         = "LRS"
    diagBlobEncryptionEnabled             = true
    sqlDatabases                          = "TestServer"
    sqlServerServiceAccountPasswordSecret = "sqlServerServiceAccountPassword"
    enableAcceleratedNetworking           = true
  }
}

variable "witnessServerConfig" {
  default = {
    vmSize = "Standard_DS2_v2"
    vmName = "TST-SVR"
    imageReference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2016-Datacenter"
      version   = "latest"
    }
    dataDisks = {
      diskSizeGB = "128"
    }
    sqlStorageAccountTier            = "Standard"
    sqlStorageAccountKind            = "StorageV2"
    sqlStorageAccountReplicationType = "LRS"
    enableAcceleratedNetworking      = true

  }
}

variable "adConfig" {
  default = {
    "domainName" : "shared.pws3.pspc-spac.ca",
    "serverOUPath" : "OU=Servers,OU=DG2,OU=GCCASE,OU=GCPS,OU=Applications,OU=PSPC,DC=shared,DC=pws3,DC=pspc-spac,DC=ca",
    "accountOUPath" : "OU=Service Accounts,OU=DG2,OU=GCCASE,OU=GCPS,OU=Applications,OU=PSPC,DC=shared,DC=pws3,DC=pspc-spac,DC=ca"
  }
}


variable "backupConfig" {
  default = {
    existingBackupVaultRG   = "AzPwS01-Shared-CRM-Backup-RG"
    existingBackupVaultName = "AzPwS01-Shared-CRM-Backup-Vault"
    existingBackupPolicy    = "DailyBackupPolicy"
  }
}

variable "env" {}
variable "group" {}
variable "project" {}

variable "tags" {
  default = {
    "workload"        = "Database"
    "owner"           = "john.nephin@tpsgc-pwgsc.gc.ca"
    "businessUnit"    = "PSPC-CCC"
    "costCenterOwner" = "PSPC-EA"
    "environment"     = "Sandbox"
    "classification"  = "Unclassified"
    "version"         = "0.1"
  }
}


