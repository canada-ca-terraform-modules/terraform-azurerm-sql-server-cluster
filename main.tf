# Template for SQL Server Cluster
# Note if running this many times for testing make sure to delete the AD and DNS objects

locals {
   lbSettings =  {
            sqlLBFE= "${var.sqlServerConfig.sqlLBName}-FE"
            sqlLBBE= "${var.sqlServerConfig.sqlLBName}-BE"
            sqlLBName= "${var.sqlServerConfig.sqlLBName}"
        }

        SQLAOProbe= "SQLAlwaysOnEndPointProbe"

        vmSettings= {
            availabilitySets= {
                sqlAvailabilitySetName= "${var.sqlServerConfig.vmName}-AS"
            }
            rdpPort= 3389
        }
        sqlAOEPName = "${var.sqlServerConfig.vmName}-HADR"
        sqlAOAGName = "${var.sqlServerConfig.vmName}-AG"       
        sqlAOListenerName = "${var.sqlServerConfig.vmName}L"
        sharePath =  "${var.sqlServerConfig.vmName}-FSW"
        clusterName = "${var.sqlServerConfig.vmName}C"
        sqlwNicName = "${var.witnessServerConfig.vmName}-NIC"
        keyVaultId = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}


resource "random_string" "random" {
  length = 8
  special = false
  upper = false
  keepers = {
        #generate new ID only when a new resource group is creted
        resource_group = "${var.resource_group_name}"
  }
}

#Create the diagnostic storage account
resource "azurerm_storage_account" "sqldiag" {
      name = "sqldiag${random_string.random.result}"
      resource_group_name = "${var.resource_group_name}"
      location = "${var.location}"
      tags = "${var.tagValues}"
      account_kind = "Storage"
      account_tier = "${var.sqlServerConfig.storageAccountTier}"
      account_replication_type = "${var.sqlServerConfig.storageAccountReplicationType}"
      enable_blob_encryption = "${var.sqlServerConfig.diagBlobEncryptionEnabled}"
    }

#Create the storage account that will hold the SQL Backups
resource "azurerm_storage_account" "sqlbackup" {
      name = "sqlbackup${random_string.random.result}"
      location = "${var.location}"
      resource_group_name = "${var.resource_group_name}"
      tags = "${var.tagValues}"
      account_tier = "${var.sqlServerConfig.storageAccountTier}"
      account_replication_type = "${var.sqlServerConfig.storageAccountReplicationType}"
      enable_blob_encryption = "${var.sqlServerConfig.sqlBackupConfig.enableEncryption}"
    }

#Create the SQL Load Balencer
resource "azurerm_lb" "sqlLB" {
      name = local.lbSettings.sqlLBName
      location = "${var.location}"
      resource_group_name = "${var.resource_group_name}"
      frontend_ip_configuration {
          name = local.lbSettings.sqlLBFE
          private_ip_address_allocation  = "Static"
          private_ip_address = "${var.sqlServerConfig.sqlLBIPAddress}"
          subnet_id = data.azurerm_subnet.subnet.id
      }
      
}

#Create the load balencer backend pool
resource "azurerm_lb_backend_address_pool" "sqlLBBE" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                = local.lbSettings.sqlLBBE
}

#Add the first VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm1BEAssoc" {
  network_interface_id    = "${module.sqlvm1.Nic0.id}"
  ip_configuration_name   = "${module.sqlvm1.Nic0.ip_configuration[0].name}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.sqlLBBE.id}"
}

#Add the second VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm2BEAssoc" {
  network_interface_id    = "${module.sqlvm2.Nic0.id}"
  ip_configuration_name   = "${module.sqlvm2.Nic0.ip_configuration[0].name}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.sqlLBBE.id}"
}

#Create the load balencer rules
resource "azurerm_lb_rule" "sqlLBRule" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = local.lbSettings.sqlLBFE
  probe_id = "${azurerm_lb_probe.sqlLBProbe.id}"
}

#Create a health probe for the load balencer
resource "azurerm_lb_probe" "sqlLBProbe" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                =  local.SQLAOProbe
  port                = 59999
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes = 2
}      

#Create the primary SQL server
module "sqlvm1" {
  source = "../terraform-azurerm-basicwindowsvm"

  name                    = "${var.sqlServerConfig.vmName}1"
  resource_group_name = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password          = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.name}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.sqlServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.sqlServerConfig.dataDisks.diskSizeGB}", "${var.sqlServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.sqlServerConfig.imageReference.sqlImagePublisher}"
    offer     = "${var.sqlServerConfig.imageReference.offer}"
    sku       = "${var.sqlServerConfig.imageReference.sku}"
    version   = "${var.sqlServerConfig.imageReference.version}"
  }
}

#Create the secondary SQL Server
module "sqlvm2" {
  source = "../terraform-azurerm-basicwindowsvm"

  name                    = "${var.sqlServerConfig.vmName}2"
  resource_group_name = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password      = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.name}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.sqlServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.sqlServerConfig.dataDisks.diskSizeGB}", "${var.sqlServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.sqlServerConfig.imageReference.sqlImagePublisher}"
    offer     = "${var.sqlServerConfig.imageReference.offer}"
    sku       = "${var.sqlServerConfig.imageReference.sku}"
    version   = "${var.sqlServerConfig.imageReference.version}"
  }
  
}

#Create the SQL Witness.  Could be switched for a blob storage if desired
module "sqlvmw" {
  source = "../terraform-azurerm-basicwindowsvm"

  name                    = "${var.sqlServerConfig.vmName}W"
  resource_group_name = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password      = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.name}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.witnessServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.witnessServerConfig.dataDisks.diskSizeGB}", "${var.witnessServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.witnessServerConfig.imageReference.publisher}"
    offer     = "${var.witnessServerConfig.imageReference.offer}"
    sku       = "${var.witnessServerConfig.imageReference.sku}"
    version   = "${var.witnessServerConfig.imageReference.version}"
  }
}

#Create the SQL Availiability Sets for hardware and update redundancy
resource "azurerm_availability_set" "sqlAS" {
  name                = "${var.sqlServerConfig.vmName}-AS"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  managed = true
}

#Configure the fileshare witness
resource "azurerm_virtual_machine_extension" "CreateFileShareWitness" {
  name                 = "CreateFileShareWitness"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  virtual_machine_name = "${var.sqlServerConfig.vmName}W"
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on = [module.sqlvmw, azurerm_storage_account.sqlbackup]
  settings = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/CreateFileShareWitness.ps1.zip",
                    "configurationFunction": "CreateFileShareWitness.ps1\\CreateFileShareWitness",
                    "properties": {
                        "domainName": "${var.adConfig.domainName}",
                        "SharePath": "${var.sqlServerConfig.vmName}-FSW",
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
                        "domainPassword": "${data.azurerm_key_vault_secret.domainAdminPasswordSecret.value}"
                }
        }
    PROTECTED_SETTINGS
}

#Prepare the servers for Always On.  
#Adds FailOver windows components, joins machines to AD, adjusts firewall rules and adds sql service account
resource "azurerm_virtual_machine_extension" "PrepareAlwaysOn" {
  name                 = "PrepareAlwaysOn"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  virtual_machine_name = "${var.sqlServerConfig.vmName}1"
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on = [azurerm_virtual_machine_extension.CreateFileShareWitness,module.sqlvm1,azurerm_template_deployment.sqlvm]
  settings = <<SETTINGS
            {
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/PrepareAlwaysOnSqlServer.ps1.zip",
                "configurationFunction": "PrepareAlwaysOnSqlServer.ps1\\PrepareAlwaysOnSqlServer",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "sqlAlwaysOnEndpointName": "${var.sqlServerConfig.vmName}-HADR",
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
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  virtual_machine_name = "${var.sqlServerConfig.vmName}2"
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.71"
  depends_on = [azurerm_virtual_machine_extension.PrepareAlwaysOn,module.sqlvm2,azurerm_template_deployment.sqlvm]
  settings = <<SETTINGS
            {
                
                "modulesURL": "https://raw.githubusercontent.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster/20190917.1/DSC/CreateFailoverCluster.ps1.zip",
                "configurationFunction": "CreateFailoverCluster.ps1\\CreateFailoverCluster",
                "properties": {
                    "domainName": "${var.adConfig.domainName}",
                    "clusterName": "${var.sqlServerConfig.vmName}C",
                    "sharePath": "\\\\${var.sqlServerConfig.vmName}W\\${var.sqlServerConfig.vmName}-FSW",
                    "nodes": [
                        "${var.sqlServerConfig.vmName}1",
                        "${var.sqlServerConfig.vmName}2"
                    ],
                    "sqlAlwaysOnEndpointName": "${var.sqlServerConfig.vmName}-HADR",
                    "sqlAlwaysOnAvailabilityGroupName": "${var.sqlServerConfig.vmName}-AG",
                    "sqlAlwaysOnAvailabilityGroupListenerName": "${var.sqlServerConfig.vmName}L",
                    "SqlAlwaysOnAvailabilityGroupListenerPort": "${var.sqlServerConfig.sqlAOListenerPort}",
                    "lbName": "${var.sqlServerConfig.sqlLBName}",
                    "lbAddress": "${var.sqlServerConfig.sqlLBIPAddress}",
                    "primaryReplica": "${var.sqlServerConfig.vmName}2",
                    "secondaryReplica": "${var.sqlServerConfig.vmName}1",
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
  resource_group_name = "${var.resource_group_name}"
  template_body = data.template_file.sqlvm.rendered
  depends_on = [module.sqlvm2,module.sqlvm1]
  #DEPLOY
 
  # =============== ARM TEMPLATE PARAMETERS =============== #
  parameters = {
    "sqlVMName" = "${var.sqlServerConfig.vmName}"
    location = "${var.location}"
    "sqlAutopatchingDayOfWeek" = "${var.sqlServerConfig.sqlpatchingConfig.dayOfWeek}"
    "sqlAutopathingEnabled" = "${var.sqlServerConfig.sqlpatchingConfig.patchingEnabled}"
    "sqlAutopatchingStartHour" = "${var.sqlServerConfig.sqlpatchingConfig.maintenanceWindowStartingHour}"
    "sqlAutopatchingWindowDuration" = "${var.sqlServerConfig.sqlpatchingConfig.maintenanceWindowDuration}"
    "sqlAutoBackupEnabled" = "${var.sqlServerConfig.sqlBackupConfig.backupEnabled}"
    "sqlAutoBackupRetentionPeriod" = "${var.sqlServerConfig.sqlBackupConfig.retentionPeriod}"
    "sqlAutoBackupEnableEncryption" = "${var.sqlServerConfig.sqlBackupConfig.enableEncryption}"
    "sqlAutoBackupSystemDbs" = "${var.sqlServerConfig.sqlBackupConfig.backupSystemDbs}"
    "sqlAutoBackupScheduleType" = "${var.sqlServerConfig.sqlBackupConfig.backupScheduleType}"
    "sqlAutoBackupFrequency" = "${var.sqlServerConfig.sqlBackupConfig.fullBackupFrequency}"
    "sqlAutoBackupFullBackupStartTime" = "${var.sqlServerConfig.sqlBackupConfig.fullBackupStartTime}"
    "sqlAutoBackupFullBackupWindowHours" = "${var.sqlServerConfig.sqlBackupConfig.fullBackupWindowHours}"
    "sqlAutoBackuplogBackupFrequency" = "${var.sqlServerConfig.sqlBackupConfig.logBackupFrequency}"
    "sqlAutoBackupPassword" = "${var.sqlServerConfig.sqlBackupConfig.password}"
    "numberOfDisks" = "${var.sqlServerConfig.dataDisks.numberOfSqlVMDisks}"
    "workloadType" = "${var.sqlServerConfig.workloadType}"
    "rServicesEnabled" = "false"
    "sqlConnectivityType" = "Private"
    "sqlPortNumber" = "1433"
    "sqlStorageDisksConfigurationType" = "NEW"
    "sqlStorageStartingDeviceId" = "2"
    "sqlServerLicenseType" = "${var.sqlServerConfig.sqlServerLicenseType}"
    "sqlStorageAccountName" = "sqlbackup${random_string.random.result}"
  }
 
  deployment_mode = "Incremental"                                          # Deployment => incremental (complete is too destructive in our case) 
}