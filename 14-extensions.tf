
#Configure the fileshare witness
resource "azurerm_virtual_machine_extension" "CreateFileShareWitness" {
  name                 = "CreateFileShareWitness"
  virtual_machine_id   = module.sqlvmw.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [module.sqlvmw, module.sqlbackup]
  settings             = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/CreateFileShareWitness.ps1.zip",
                    "configurationFunction": "CreateFileShareWitness.ps1\\CreateFileShareWitness",
                    "properties": {
                        "domainName": "${var.adConfig.domainName}",
                        "SharePath": "${local.sharePath}",
                        "domainCreds": {
                            "userName": "${var.domainUsername}",
                            "password": "privateSettingsRef:domainPassword"
                        },
                        "ouPath": "${var.adConfig.serverOUPath}"
                    }
            }
            SETTINGS
  protected_settings   = <<PROTECTED_SETTINGS
         {
      "Items": {
                        "domainPassword": "${data.azurerm_key_vault_secret.domainAdminPasswordSecret.value}"
                }
        }
    PROTECTED_SETTINGS
}

#Prepare the servers for Always On.  
#Adds FailOver windows components, joins machines to AD, adjusts firewall rules and adds sql service account
resource "azurerm_virtual_machine_extension" "PrepareAlwaysOn" {
  name                 = "PrepareAlwaysOn"
  virtual_machine_id   = module.sqlvm1.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [azurerm_virtual_machine_extension.CreateFileShareWitness, module.sqlvm1, azurerm_template_deployment.sqlvm]
  settings             = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/PrepareAlwaysOnSqlServer.ps1.zip",
                "configurationFunction": "PrepareAlwaysOnSqlServer.ps1\\PrepareAlwaysOnSqlServer",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "sqlAlwaysOnEndpointName": "${var.sqlServerConfig.vmName}-hadr",
                    "adminCreds": {
                        "userName": "${var.adminUsername}",
                        "password": "privateSettingsRef:AdminPassword"
                    },
                    "domainCreds": {
                        "userName": "${var.domainUsername}",
                        "password": "privateSettingsRef:domainPassword"
                    },
                    "sqlServiceCreds": {
                        "userName": "${var.sqlServerConfig.sqlServerServiceAccountUserName}",
                        "password": "privateSettingsRef:SqlServerServiceAccountPassword"
                    },
                    "NumberOfDisks": "${var.sqlServerConfig.dataDisks.numberOfSqlVMDisks}",
                    "WorkloadType": "${var.sqlServerConfig.workloadType}",
                    "serverOUPath": "${var.adConfig.serverOUPath}",
                    "accountOUPath": "${var.adConfig.accountOUPath}"
                }
            }
            SETTINGS
  protected_settings   = <<PROTECTED_SETTINGS
         {
      "Items": {
                        "domainPassword": "${data.azurerm_key_vault_secret.domainAdminPasswordSecret.value}",
                        "adminPassword": "${data.azurerm_key_vault_secret.localAdminPasswordSecret.value}",
                        "sqlServerServiceAccountPassword": "${data.azurerm_key_vault_secret.sqlAdminPasswordSecret.value}"
                }
        }
    PROTECTED_SETTINGS
}

#Deploy the failover cluster
resource "azurerm_virtual_machine_extension" "CreateFailOverCluster" {
  name                 = "configuringAlwaysOn"
  virtual_machine_id   = module.sqlvm2.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [azurerm_virtual_machine_extension.PrepareAlwaysOn, module.sqlvm2, azurerm_template_deployment.sqlvm]
  settings             = <<SETTINGS
            {
                
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/CreateFailoverCluster.ps1.zip",
                "configurationFunction": "CreateFailoverCluster.ps1\\CreateFailoverCluster",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "clusterName": "${local.clusterName}",
                    "sharePath": "\\\\${local.witnessName}\\${local.sharePath}",
                    "nodes": [
                        "${local.vm1Name}",
                        "${local.vm2Name}"
                    ],
                    "sqlAlwaysOnEndpointName": "${local.sqlAOEPName}",
                    "sqlAlwaysOnAvailabilityGroupName": "${local.sqlAOAGName}",
                    "sqlAlwaysOnAvailabilityGroupListenerName": "${local.sqlAOListenerName}",
                    "SqlAlwaysOnAvailabilityGroupListenerPort": "${var.sqlServerConfig.sqlAOListenerPort}",
                    "lbName": "${var.sqlServerConfig.sqlLBName}",
                    "lbAddress": "${var.sqlServerConfig.sqlLBIPAddress}",
                    "primaryReplica": "${local.vm2Name}",
                    "secondaryReplica": "${local.vm1Name}",
                    "dnsServerName": "${var.dnsServerName}",
                    "adminCreds": {
                        "userName": "${var.adminUsername}",
                        "password": "privateSettingsRef:adminPassword"
                    },
                    "domainCreds": {
                        "userName": "${var.domainUsername}",
                        "password": "privateSettingsRef:domainPassword"
                    },
                    "sqlServiceCreds": {
                        "userName": "${var.sqlServerConfig.sqlServerServiceAccountUserName}",
                        "password": "privateSettingsRef:sqlServerServiceAccountPassword"
                    },
                    "SQLAuthCreds": {
                        "userName": "sqlsa",
                        "password": "privateSettingsRef:sqlAuthPassword"
                    },
                    "NumberOfDisks": "${var.sqlServerConfig.dataDisks.numberOfSqlVMDisks}",
                    "WorkloadType": "${var.sqlServerConfig.workloadType}",
                    "serverOUPath": "${var.adConfig.serverOUPath}",
                    "accountOUPath": "${var.adConfig.accountOUPath}",
                    "DatabaseNames": "${var.sqlServerConfig.sqlDatabases}",
                    "ClusterIp": "${var.sqlServerConfig.clusterIp}"
                }
            }
            SETTINGS
  protected_settings   = <<PROTECTED_SETTINGS
         {
      "Items": {
                    "adminPassword": "${data.azurerm_key_vault_secret.localAdminPasswordSecret.value}",
                    "domainPassword": "${data.azurerm_key_vault_secret.domainAdminPasswordSecret.value}",
                    "sqlServerServiceAccountPassword": "${data.azurerm_key_vault_secret.sqlAdminPasswordSecret.value}",
                    "sqlAuthPassword": "${data.azurerm_key_vault_secret.sqlAdminPasswordSecret.value}"
                }
        }
    PROTECTED_SETTINGS
}

#Convert the VM's to SqlServer Type for added features (backup, patching, BYOL hybrid, disk scalability)
#The sql VM types are not supported by terraform yet so we need to call an ARM template for this piece
resource "azurerm_template_deployment" "sqlvm" {
  name                = "${var.sqlServerConfig.vmName}-template"
  resource_group_name = var.resource_group_name
  template_body       = data.template_file.sqlvm.rendered
  depends_on          = [module.sqlvm2, module.sqlvm1]
  #DEPLOY

  # =============== ARM TEMPLATE PARAMETERS =============== #
  parameters = {
    "sqlVMName"                          = "${var.sqlServerConfig.vmName}"
    location                             = "${var.location}"
    "sqlAutopatchingDayOfWeek"           = "${var.sqlServerConfig.sqlpatchingConfig.dayOfWeek}"
    "sqlAutopathingEnabled"              = "${var.sqlServerConfig.sqlpatchingConfig.patchingEnabled}"
    "sqlAutopatchingStartHour"           = "${var.sqlServerConfig.sqlpatchingConfig.maintenanceWindowStartingHour}"
    "sqlAutopatchingWindowDuration"      = "${var.sqlServerConfig.sqlpatchingConfig.maintenanceWindowDuration}"
    "sqlAutoBackupEnabled"               = "${var.sqlServerConfig.sqlBackupConfig.backupEnabled}"
    "sqlAutoBackupRetentionPeriod"       = "${var.sqlServerConfig.sqlBackupConfig.retentionPeriod}"
    "sqlAutoBackupEnableEncryption"      = "${var.sqlServerConfig.sqlBackupConfig.enableEncryption}"
    "sqlAutoBackupSystemDbs"             = "${var.sqlServerConfig.sqlBackupConfig.backupSystemDbs}"
    "sqlAutoBackupScheduleType"          = "${var.sqlServerConfig.sqlBackupConfig.backupScheduleType}"
    "sqlAutoBackupFrequency"             = "${var.sqlServerConfig.sqlBackupConfig.fullBackupFrequency}"
    "sqlAutoBackupFullBackupStartTime"   = "${var.sqlServerConfig.sqlBackupConfig.fullBackupStartTime}"
    "sqlAutoBackupFullBackupWindowHours" = "${var.sqlServerConfig.sqlBackupConfig.fullBackupWindowHours}"
    "sqlAutoBackuplogBackupFrequency"    = "${var.sqlServerConfig.sqlBackupConfig.logBackupFrequency}"
    "sqlAutoBackupPassword"              = "${var.sqlServerConfig.sqlBackupConfig.password}"
    "numberOfDisks"                      = "${var.sqlServerConfig.dataDisks.numberOfSqlVMDisks}"
    "workloadType"                       = "${var.sqlServerConfig.workloadType}"
    "rServicesEnabled"                   = "false"
    "sqlConnectivityType"                = "Private"
    "sqlPortNumber"                      = "1433"
    "sqlStorageDisksConfigurationType"   = "NEW"
    "sqlStorageStartingDeviceId"         = "2"
    "sqlServerLicenseType"               = "${var.sqlServerConfig.sqlServerLicenseType}"
    "sqlStorageAccountName"              = "${local.backupStorageName}"
  }

  deployment_mode = "Incremental" # Deployment => incremental (complete is too destructive in our case) 
}
