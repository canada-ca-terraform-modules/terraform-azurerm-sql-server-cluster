
#Configure the fileshare witness
resource "azurerm_virtual_machine_extension" "CreateFileShare" {
  name                 = "CreateFileShare"
  virtual_machine_id   = module.sqlvmw.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [module.sqlvmw, module.sqlbackup]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  settings           = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20200916.1/DSC/CreateFileShare.ps1.zip",
                    "configurationFunction": "CreateFileShare.ps1\\CreateFileShare",
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
  protected_settings = <<PROTECTED_SETTINGS
         {
      "Items": {
                        "domainPassword": "var.keyVaultConfig.domainAdminPasswordSecret"
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
  depends_on           = [azurerm_virtual_machine_extension.CreateFileShare, module.sqlvm1, azurerm_template_deployment.sqlvm1, azurerm_template_deployment.sqlvm2]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  settings           = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20200916.1/DSC/PrepareAlwaysOnSqlServer.ps1.zip",
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
  protected_settings = <<PROTECTED_SETTINGS
         {
      "Items": {
                        "domainPassword": "var.keyVaultConfig.domainAdminPasswordSecret",
                        "adminPassword": "${var.sqlServerConfig.}",
                        "sqlServerServiceAccountPassword": "${var.sqlServerConfig.sqlBackupConfig.password}"
                }
        }
    PROTECTED_SETTINGS
}

#Deploy the failover cluster
resource "azurerm_virtual_machine_extension" "CreateFailOverCluster" {
  name                 = "configuringAlwaysOn"
  virtual_machine_id   = module.sqlvm1.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [azurerm_virtual_machine_extension.PrepareAlwaysOn, module.sqlvm2, azurerm_template_deployment.sqlvm1, azurerm_template_deployment.sqlvm2]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  settings           = <<SETTINGS
            {
                
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20200916.1/DSC/CreateFailoverCluster.ps1.zip",
                "configurationFunction": "CreateFailoverCluster.ps1\\CreateFailoverCluster",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "clusterName": "${local.clusterName}",
                    "sharePath": "\\\\${module.sqlvmw.name}\\${local.sharePath}",
                    "nodes": [
                        "${module.sqlvm1.name}",
                        "${module.sqlvm2.name}"
                    ],
                    "sqlAlwaysOnEndpointName": "${local.sqlAOEPName}",
                    "sqlAlwaysOnAvailabilityGroupName": "${local.sqlAOAGName}",
                    "sqlAlwaysOnAvailabilityGroupListenerName": "${local.sqlAOListenerName}",
                    "SqlAlwaysOnAvailabilityGroupListenerPort": "${var.sqlServerConfig.sqlAOListenerPort}",
                    "lbName": "${var.sqlServerConfig.sqlLBName}",
                    "lbAddress": "${var.sqlServerConfig.sqlLBIPAddress}",
                    "primaryReplica": "${module.sqlvm2.name}",
                    "secondaryReplica": "${module.sqlvm1.name}",
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
  protected_settings = <<PROTECTED_SETTINGS
         {
      "Items": {
                    "adminPassword": "${var.sqlServerConfig.}",
                    "domainPassword": "var.keyVaultConfig.domainAdminPasswordSecret",
                    "sqlServerServiceAccountPassword": "${var.sqlServerConfig.sqlBackupConfig.password}",
                    "sqlAuthPassword": "${var.sqlServerConfig.sqlBackupConfig.password}"
                }
        }
    PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "JoinFailOverCluster" {
  name                 = "JoinFailOverCluster"
  virtual_machine_id   = module.sqlvm2.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on           = [azurerm_virtual_machine_extension.PrepareAlwaysOn, module.sqlvm2, azurerm_template_deployment.sqlvm1, azurerm_template_deployment.sqlvm2, azurerm_virtual_machine_extension.CreateFailOverCluster]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  settings           = <<SETTINGS
            {
                
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20200916.1/DSC/CreateFailoverCluster.ps1.zip",
                "configurationFunction": "SecondaryFailoverCluster.ps1\\SecondaryFailoverCluster",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "clusterName": "${local.clusterName}",
                    "sharePath": "\\\\${module.sqlvmw.name}\\${local.sharePath}",
                    "nodes": [
                        "${module.sqlvm1.name}",
                        "${module.sqlvm2.name}"
                    ],
                    "sqlAlwaysOnEndpointName": "${local.sqlAOEPName}",
                    "sqlAlwaysOnAvailabilityGroupName": "${local.sqlAOAGName}",
                    "sqlAlwaysOnAvailabilityGroupListenerName": "${local.sqlAOListenerName}",
                    "SqlAlwaysOnAvailabilityGroupListenerPort": "${var.sqlServerConfig.sqlAOListenerPort}",
                    "lbName": "${var.sqlServerConfig.sqlLBName}",
                    "lbAddress": "${var.sqlServerConfig.sqlLBIPAddress}",
                    "primaryReplica": "${module.sqlvm2.name}",
                    "secondaryReplica": "${module.sqlvm1.name}",
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
                    "ClusterIp": "${var.sqlServerConfig.clusterIp}",
                    "SecondaryNode": "$true"
                }
            }
            SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
         {
      "Items": {
                    "adminPassword": "${var.sqlServerConfig.sqlBackupConfig.password}",
                    "domainPassword": "${var.sqlServerConfig.sqlBackupConfig.password}",
                    "sqlServerServiceAccountPassword": "${var.sqlServerConfig.sqlBackupConfig.password}",
                    "sqlAuthPassword": "${var.sqlServerConfig.sqlBackupConfig.password}"
                }
        }
    PROTECTED_SETTINGS
}

#Convert the VM's to SqlServer Type for added features (backup, patching, BYOL hybrid, disk scalability)
#The sql VM types are not supported by terraform yet so we need to call an ARM template for this piece
resource "azurerm_template_deployment" "sqlvm1" {
  name                = "${module.sqlvm1.name}-template"
  resource_group_name = var.resource_group.name
  template_body       = data.template_file.sqlvm.rendered
  depends_on          = [module.sqlvm2, module.sqlvm1]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  #DEPLOY

  # =============== ARM TEMPLATE PARAMETERS =============== #
  parameters = {
    "sqlVMName"                          = "${module.sqlvm1.name}"
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
    "sqlStorageAccountName"              = "${module.sqlbackup.name}"
  }

  deployment_mode = "Incremental" # Deployment => incremental (complete is too destructive in our case) 
}
resource "azurerm_template_deployment" "sqlvm2" {
  name                = "${module.sqlvm2.name}-template"
  resource_group_name = var.resource_group.name
  template_body       = data.template_file.sqlvm.rendered
  depends_on          = [module.sqlvm2, module.sqlvm1]
  timeouts {
    create = "2h"
    delete = "2h"
  }
  #DEPLOY

  # =============== ARM TEMPLATE PARAMETERS =============== #
  parameters = {
    "sqlVMName"                          = "${module.sqlvm2.name}"
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
    "sqlStorageAccountName"              = "${module.sqlbackup.name}"
  }

  deployment_mode = "Incremental" # Deployment => incremental (complete is too destructive in our case) 
}
