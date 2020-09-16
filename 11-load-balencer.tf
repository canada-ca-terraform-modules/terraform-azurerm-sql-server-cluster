locals {

  lbSettings = {
    sqlLBFE   = "${var.sqlServerConfig.sqlLBName}-lbfe"
    sqlLBBE   = "${var.sqlServerConfig.sqlLBName}-lbbe"
    sqlLBName = "${var.sqlServerConfig.sqlLBName}-lb"
  }

  SQLAOProbe = "SQLAlwaysOnEndPointProbe"

}
#Create the SQL Load Balencer
resource "azurerm_lb" "sqlLB" {
  name                = local.lbSettings.sqlLBName
  location            = var.location
  resource_group_name = var.resource_group.name
  frontend_ip_configuration {
    name                          = local.lbSettings.sqlLBFE
    private_ip_address_allocation = "Static"
    private_ip_address            = var.sqlServerConfig.sqlLBIPAddress
    subnet_id                     = var.vnetConfig.sqlSubnet.id
  }

}

#Create the load balencer backend pool
resource "azurerm_lb_backend_address_pool" "sqlLBBE" {
  resource_group_name = var.resource_group.name
  loadbalancer_id     = azurerm_lb.sqlLB.id
  name                = local.lbSettings.sqlLBBE
}

#Add the first VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm1BEAssoc" {
  network_interface_id    = module.sqlvm1.nic.id
  ip_configuration_name   = module.sqlvm1.nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.sqlLBBE.id
}

#Add the second VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm2BEAssoc" {
  network_interface_id    = module.sqlvm2.nic.id
  ip_configuration_name   = module.sqlvm2.nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.sqlLBBE.id
}

#Create the load balencer rules
resource "azurerm_lb_rule" "sqlLBRule" {
  resource_group_name            = var.resource_group.name
  loadbalancer_id                = azurerm_lb.sqlLB.id
  name                           = "${local.lbSettings.sqlLBName}-lbr"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = local.lbSettings.sqlLBFE
  probe_id                       = azurerm_lb_probe.sqlLBProbe.id
}

#Create a health probe for the load balencer
resource "azurerm_lb_probe" "sqlLBProbe" {
  resource_group_name = var.resource_group.name
  loadbalancer_id     = azurerm_lb.sqlLB.id
  name                = local.SQLAOProbe
  port                = 59999
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}
